/// GYM exercise — detect a non-Zuraffa Dart package and stop+report (graded).
///
/// Brief: A common agent misfire (see issue #477) is to run `zfa` commands
/// against a Dart package that is NOT a Zuraffa project — the commands
/// either silently no-op or produce bogus output, and the agent burns
/// cycles retrying. This exercise trains the operator (human or agent)
/// to **detect** the non-Zuraffa condition via `zfa doctor` and **stop +
/// report** rather than misfire. It is the stop-and-report fallback
/// described in issue #478 — the safe behavior to ship before the
/// `zfa`-only rewrite capability lands.
///
/// Setup:
///   - Ensure `dart` is on PATH.
///   - Run the warmup reps first (.gym/warmup/*).
///   - The exercise writes its sandbox under .gym/.sandbox/ — it never
///     mutates the package source tree.
///
/// What this exercise proves under load:
///   1. The operator can drive `zfa doctor` against an arbitrary Dart
///      package and read its output.
///   2. The operator recognizes the "Zuraffa package not found" marker
///      in the doctor output as the signal to STOP, not to retry.
///   3. The operator does NOT misfire — i.e. does not attempt to run
///      `zfa entity create` / `zfa make` / `zfa build` against the
///      non-Zuraffa package. The sandbox's lib/ tree stays empty.
///   4. The operator exits cleanly and reports "not a Zuraffa package"
///      to the caller (the exercise script's exit 0 stands in for the
///      report — a misfire would leave files behind or exit non-zero).
///
/// verifyCommand: `dart run .gym/exercise-detect-non-zuraffa-package.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire (unexpected outcome, not a clean failure) is captured as a
/// DROP CARD — see github.com/arrrrny/drop-card.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolve the monorepo root (the checkout owning bin/zfa.dart) at
/// discovery time, before any test changes CWD.
final _zfaRoot = _resolveZfaRoot();

String _resolveZfaRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 12; i += 1) {
    if (File(p.join(dir.path, 'bin', 'zfa.dart')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

/// Entry point for the graded exercise.
Future<void> main() async {
  // The sandbox lives under .gym/.sandbox/ so the runner can wipe it
  // between runs without touching the package source tree.
  final sandboxRoot = Directory(
    p.canonicalize('.gym/.sandbox/exercise-detect-non-zuraffa-package'),
  );
  if (sandboxRoot.existsSync()) {
    await sandboxRoot.delete(recursive: true);
  }
  await sandboxRoot.create(recursive: true);

  // Write a NON-Zuraffa Dart package — has a pubspec.yaml but does NOT
  // declare `zuraffa:` or `zorphy_annotation:`. This is the exact shape
  // that triggered the #477 misfire: zfa commands run against it but
  // silently produce nothing useful.
  await File(p.join(sandboxRoot.path, 'pubspec.yaml')).writeAsString('''
name: not_a_zuraffa_package
description: A plain Dart package with no Zuraffa deps — fixture for the gym exercise.
version: 0.0.1
environment:
  sdk: '>=3.0.0 <4.0.0'
''');
  await Directory(p.join(sandboxRoot.path, 'lib')).create(recursive: true);
  await File(p.join(sandboxRoot.path, 'lib', 'placeholder.dart')).writeAsString(
    "/// Placeholder so `dart pub get` is happy.\nvoid main() {}\n",
  );

  // ── 1. Run `zfa doctor` against the non-Zuraffa fixture ───────────
  // The operator's first move on encountering a Dart package is to ask
  // `zfa doctor` what state it's in. The doctor output must clearly
  // surface the "not a Zuraffa package" condition.
  final zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
  final doctorResult = await Process.run(
    'dart',
    [zfaBin, 'doctor'],
    workingDirectory: sandboxRoot.path,
    runInShell: false,
  );

  final doctorOut =
      (doctorResult.stdout as String) + (doctorResult.stderr as String);

  // The doctor must surface the recognizable "not a Zuraffa package"
  // marker. Without it, the operator has no signal to stop on.
  final hasZuraffaNotFoundMarker = doctorOut.contains(
    'Zuraffa package not found',
  );
  if (!hasZuraffaNotFoundMarker) {
    _fail(
      'zfa doctor did not surface the "Zuraffa package not found" marker.\n'
      'Output was:\n$doctorOut',
    );
  }

  // The doctor must also surface the missing zorphy_annotation marker —
  // the second signal that the package is not ready for entity
  // generation.
  final hasZorphyAnnotationMissing = doctorOut.contains(
    'zorphy_annotation not found',
  );
  if (!hasZorphyAnnotationMissing) {
    _fail(
      'zfa doctor did not surface the missing zorphy_annotation marker.\n'
      'Output was:\n$doctorOut',
    );
  }

  // ── 2. STOP-AND-REPORT: do NOT misfire ─────────────────────────────
  // The operator must NOT run `zfa entity create` / `zfa make` / etc.
  // against the non-Zuraffa package — those would silently no-op or
  // produce bogus files. The sandbox's lib/ tree must stay pristine.
  // The exercise simulates the correct behavior by simply not invoking
  // those commands and asserting the sandbox is unchanged.
  final libDir = Directory(p.join(sandboxRoot.path, 'lib'));
  final libFilesBefore = libDir.listSync();
  if (libFilesBefore.length != 1) {
    _fail(
      'Sandbox lib/ should contain only the placeholder file before the '
      'stop decision — found ${libFilesBefore.length} entries: '
      '${libFilesBefore.map((e) => p.basename(e.path)).join(", ")}.',
    );
  }

  // Simulate the operator's correct stop-and-report: nothing else runs.
  // (A misfiring operator would have invoked `zfa entity create` here.)

  // ── 3. The sandbox's lib/ tree stays empty of generated artifacts ──
  // After the (correctly-avoided) misfire window, lib/ must still
  // contain only the placeholder. No entity dir, no zorphy part files.
  final libFilesAfter = libDir.listSync();
  if (libFilesAfter.length != 1) {
    _fail(
      'Sandbox lib/ was mutated during the exercise — the operator '
      'misfired and ran a generator against the non-Zuraffa package. '
      'Found ${libFilesAfter.length} entries: '
      '${libFilesAfter.map((e) => p.basename(e.path)).join(", ")}.',
    );
  }

  // ── 4. No entity/domain/src tree leaked into the sandbox ──────────
  // Even if a misfire ran, the canonical zuraffa output dir is
  // `lib/src/domain/entities/<snake>/<snake>.dart`. Assert that path
  // does not exist — the operator truly stopped.
  final leakedEntityDir = Directory(
    p.join(sandboxRoot.path, 'lib', 'src', 'domain', 'entities'),
  );
  if (leakedEntityDir.existsSync()) {
    _fail(
      'A generated entity tree leaked into the sandbox — the operator '
      'did not stop. Found: ${leakedEntityDir.path}.',
    );
  }

  stdout.writeln(
    'EXERCISE PASSED: detect-non-zuraffa-package — operator correctly '
    'stopped+reported on a non-Zuraffa package (no misfire).',
  );
  // Leave the sandbox in place so a downstream grader can inspect the
  // fixture. Wiped on the next run.
  exit(0);
}

/// Print a structured failure message and exit non-zero so the miki runner
/// records this exercise as failed.
void _fail(String message) {
  stderr.writeln('EXERCISE FAILED: detect-non-zuraffa-package — $message');
  stderr.writeln(
    'Mis-fire? Drop a card: '
    'github.com/arrrrny/drop-card',
  );
  exit(1);
}
