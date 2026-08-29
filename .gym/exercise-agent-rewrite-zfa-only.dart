/// GYM exercise — agent rewrite of a Dart package using only zfa (graded).
///
/// Brief: Train the operator (human or agent) to REWRITE an existing Dart
/// package using ONLY the `zfa` CLI — and to STOP-AND-REPORT when the target
/// is not Zuraffa-compatible instead of misfiring (issue #478; see #477 for
/// the original misfire).
///
/// The exercise runs the trained protocol end to end on two fixed, embedded
/// fixture targets inside an isolated sandbox:
///
///   LEG A — Zuraffa-compatible target (`sample-crud-package`):
///     1. Compatibility detection FIRST via `zfa doctor` (FR-002): the output
///        must surface the `Zuraffa package found` + `zorphy_annotation found`
///        markers before any rewrite command runs.
///     2. zfa-only rewrite (FR-008): lift every entity declared in the
///        target's `rewrite-manifest.json` with `zfa entity create -n <Name>
///        --field <name:type> ...`, then generate the architecture with
///        `zfa make <Name> datasource repository usecase`.
///     3. Compilation + structure proof (FR-004): `zfa build` (build_runner +
///        embedded `dart analyze`) must report no errors, and every canonical
///        v5 path must exist:
///        `lib/src/domain/entities/<snake>/<snake>.dart`.
///
///   LEG B — non-Zuraffa target (`plain-dart-package`):
///     1. Compatibility detection via `zfa doctor` (FR-002): the output must
///        surface the `Zuraffa package not found` +
///        `zorphy_annotation not found` markers.
///     2. STOP-AND-REPORT (FR-005): no rewrite command is invoked; a
///        structured `NOT-ZURAFFA-COMPATIBLE.md` report (package, verdict,
///        why/evidence, what-would-make-it-compatible) is written beside the
///        target.
///     3. No-misfire proof: the target's `lib/` tree stays pristine and no
///        `lib/src/domain/entities/` tree appears.
///
/// Setup:
///   - Ensure `dart` is on PATH.
///   - Run the warmup reps first (.gym/warmup/*).
///   - The exercise writes its sandbox under .gym/.sandbox/ — it never
///     mutates the package source tree (FR-006). Fixture staging and
///     `dart pub get` are setup tooling (FR-008 permits non-zfa setup).
///
/// Grading (FR-007): exit 0 => pass (both legs behaved correctly — a correct
/// stop-and-report on leg B is a PASS, not a failure); exit non-zero => fail.
///
/// verifyCommand: `dart run .gym/exercise-agent-rewrite-zfa-only.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire (unexpected outcome, not a clean failure) is a DROP CARD — see
/// github.com/arrrrny/drop-card.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolve the zuraffa repo root (the checkout owning bin/zfa.dart) at
/// discovery time, before any step changes CWD.
final String _zfaRoot = _resolveZfaRoot();

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

/// Path placeholder used by the fixture pubspecs so the embedded sample
/// package can pin the local zuraffa checkout without knowing where it lives.
const String _zfaRootPlaceholder = '__ZURAFFA_ROOT__';

/// Entry point for the graded exercise.
Future<void> main() async {
  // ── SETUP (tooling; FR-008 permits non-zfa commands here) ──────────
  final zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
  if (!File(zfaBin).existsSync()) {
    _fail(
      'zfa CLI entry not found at $zfaBin — run this exercise from the '
      'zuraffa repo root.',
    );
  }

  final fixturesDir = p.join(_zfaRoot, '.gym', 'fixtures');
  final compatibleFixture = p.join(fixturesDir, 'sample-crud-package');
  final plainFixture = p.join(fixturesDir, 'plain-dart-package');

  // Fixture staging precondition (FR-003): the concrete, fixed sample
  // targets must exist in the repo.
  for (final requiredFile in <String>[
    p.join(compatibleFixture, 'pubspec.yaml'),
    p.join(compatibleFixture, 'rewrite-manifest.json'),
    p.join(compatibleFixture, 'lib', 'legacy_note.dart'),
    p.join(compatibleFixture, 'lib', 'legacy_tag.dart'),
    p.join(plainFixture, 'pubspec.yaml'),
    p.join(plainFixture, 'lib', 'main.dart'),
  ]) {
    if (!File(requiredFile).existsSync()) {
      _fail(
        'Required fixture missing: $requiredFile — the exercise targets '
        'are embedded under .gym/fixtures/ (FR-003).',
      );
    }
  }

  // Sandbox lifecycle (FR-006): wipe + create under .gym/.sandbox/.
  final sandboxRoot = Directory(
    p.canonicalize(
      p.join(_zfaRoot, '.gym', '.sandbox', 'exercise-agent-rewrite-zfa-only'),
    ),
  );
  if (sandboxRoot.existsSync()) {
    await sandboxRoot.delete(recursive: true);
  }
  await sandboxRoot.create(recursive: true);

  final target = p.join(sandboxRoot.path, 'target');
  final plainTarget = p.join(sandboxRoot.path, 'plain');

  await _copyTree(compatibleFixture, target);
  await _copyTree(plainFixture, plainTarget);

  // Normalize the zuraffa path placeholder so the sandbox target resolves
  // against THIS checkout (deterministic + offline-friendly).
  final targetPubspec = File(p.join(target, 'pubspec.yaml'));
  final pubspecText = targetPubspec.readAsStringSync();
  if (!pubspecText.contains(_zfaRootPlaceholder)) {
    _fail(
      'Fixture pubspec.yaml is missing the $_zfaRootPlaceholder path '
      'placeholder — cannot pin the sandbox to this checkout.',
    );
  }
  targetPubspec.writeAsStringSync(
    pubspecText.replaceAll(_zfaRootPlaceholder, _zfaRoot),
  );

  // Resolve the sandbox target's dependencies (setup tooling). A failure
  // here is a SETUP error, not a grade (spec edge case).
  final pubGet = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: target,
    runInShell: false,
  );
  if (pubGet.exitCode != 0) {
    _fail(
      'SETUP ERROR: dart pub get failed in the sandbox target '
      '(exit ${pubGet.exitCode}). This is an environment/setup problem, '
      'not a graded failure. Output:\n${pubGet.stdout}\n${pubGet.stderr}',
    );
  }

  // Load the deterministic rewrite manifest (FR-003: the target's data
  // model the rewrite must lift).
  final manifestFile = File(p.join(target, 'rewrite-manifest.json'));
  final Map<String, dynamic> manifest;
  try {
    manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    _fail('rewrite-manifest.json is not valid JSON: $e');
    return;
  }
  final entities = (manifest['entities'] as List<dynamic>? ?? <dynamic>[])
      .cast<Map>();

  stdout.writeln(
    'SETUP OK: sandbox staged with ${entities.length} manifest '
    'entities under ${sandboxRoot.path}',
  );

  // ── LEG A: compatible target → zfa-only rewrite ─────────────────────

  // Step 1 — compatibility detection BEFORE any rewrite command (FR-002).
  // The trained first move on encountering a Dart package is `zfa doctor`;
  // the routing decision comes from its markers, never a guess.
  final verdictA = await _detectCompatibility(target);
  if (!verdictA.compatible) {
    _fail(
      'LEG A detection: the sample-crud-package target is expected to be '
      'Zuraffa-compatible but `zfa doctor` did not surface both required '
      'markers ("Zuraffa package found", "zorphy_annotation found"). '
      'Doctor output:\n${verdictA.output}',
    );
  }
  // Mutual exclusivity: a compatible verdict must NOT co-occur with the
  // not-compatible markers (gives the detection assertions teeth).
  if (verdictA.output.contains('Zuraffa package not found')) {
    _fail(
      'LEG A detection: doctor output contains BOTH compatible and '
      'not-compatible markers — ambiguous signal.\n${verdictA.output}',
    );
  }
  stdout.writeln(
    'LEG A detection OK: Zuraffa-compatible target confirmed '
    'via zfa doctor markers.',
  );

  // ── LEG B: non-compatible target → stop-and-report ──────────────────

  // Step 1 — compatibility detection on the plain fixture (FR-002). The
  // same doctor move routes this target to STOP, never to rewrite.
  final verdictB = await _detectCompatibility(plainTarget);
  if (verdictB.compatible) {
    _fail(
      'LEG B detection: the plain-dart-package target is expected to be '
      'NOT Zuraffa-compatible but `zfa doctor` surfaced the compatible '
      'markers. Doctor output:\n${verdictB.output}',
    );
  }
  if (!verdictB.output.contains('Zuraffa package not found') ||
      !verdictB.output.contains('zorphy_annotation not found')) {
    _fail(
      'LEG B detection: doctor output for the plain package must surface '
      'both "Zuraffa package not found" and "zorphy_annotation not found" '
      'markers — they are the STOP signal an operator relies on. '
      'Output:\n${verdictB.output}',
    );
  }
  stdout.writeln(
    'LEG B detection OK: non-compatible target confirmed via '
    'zfa doctor markers — protocol routes to STOP-AND-REPORT.',
  );

  // STOP-AND-REPORT (FR-005, US2-S2): the trained behavior — write the
  // structured report, invoke nothing else. This is the artifact the
  // exercise grades; a misfiring operator would have run `zfa entity
  // create` here instead.
  await File(p.join(plainTarget, 'NOT-ZURAFFA-COMPATIBLE.md')).writeAsString(
    _stopAndReport(
      packageName: 'plain_dart_package',
      packagePath: plainTarget,
      doctorOutput: verdictB.output,
    ),
  );
  stdout.writeln(
    'LEG B stop-and-report OK: NOT-ZURAFFA-COMPATIBLE.md '
    'written; no rewrite command invoked.',
  );

  // Step 2 — zfa-only rewrite: lift every manifest entity (FR-008).
  for (final entity in entities) {
    final name = entity['name'] as String;
    final fields = (entity['fields'] as List<dynamic>).cast<Map>();
    final args = <String>['entity', 'create', '-n', name];
    for (final field in fields) {
      args.addAll([
        '--field',
        '${field['name'] as String}:${field['type'] as String}',
      ]);
    }
    final createResult = await _runZfa(target, args);
    if (createResult.exitCode != 0) {
      _fail(
        'LEG A step 2: `zfa entity create -n $name` exited '
        '${createResult.exitCode}.\n${createResult.output}',
      );
    }
  }
  stdout.writeln(
    'LEG A step 2 OK: ${entities.length} entities created via '
    'zfa entity create.',
  );

  // Step 3 — architecture generation, still zfa-only (FR-001, FR-008).
  final makePlugins = (manifest['makePlugins'] as List<dynamic>? ?? [])
      .cast<String>()
      .toList();
  if (makePlugins.isEmpty) {
    _fail(
      'LEG A step 3: rewrite-manifest.json declares no makePlugins — '
      'the rewrite has no architecture to generate.',
    );
  }
  for (final entity in entities) {
    final name = entity['name'] as String;
    final makeResult = await _runZfa(target, ['make', name, ...makePlugins]);
    if (makeResult.exitCode != 0) {
      _fail(
        'LEG A step 3: `zfa make $name ${makePlugins.join(' ')}` exited '
        '${makeResult.exitCode}.\n${makeResult.output}',
      );
    }
  }
  stdout.writeln(
    'LEG A step 3 OK: architecture generated via zfa make '
    '(${makePlugins.join(' ')}).',
  );

  // Step 4 — compilation proof (FR-004): `zfa build` runs build_runner
  // codegen and its embedded `dart analyze` must report no errors.
  final buildResult = await _runZfa(target, ['build']);
  if (buildResult.exitCode != 0 ||
      !buildResult.output.contains('dart analyze: no errors')) {
    _fail(
      'LEG A step 4: `zfa build` did not prove compilation '
      '(exit ${buildResult.exitCode}).\n${buildResult.output}',
    );
  }
  stdout.writeln(
    'LEG A step 4 OK: zfa build compiled the rewritten package '
    '(dart analyze: no errors).',
  );

  // ── LEG A verification (FR-004) ─────────────────────────────────────
  // Written before the protocol steps were wired (cycle 3 red evidence:
  // every assertion below failed with a named missing artifact while the
  // invocations were absent).
  for (final entity in entities) {
    final name = entity['name'] as String;
    final snake = _snakeCase(name);
    final fields = (entity['fields'] as List<dynamic>).cast<Map>();

    // Canonical v5 entity layout (US1-S3): one entity per snake dir.
    final entityFile = File(
      p.join(target, 'lib', 'src', 'domain', 'entities', snake, '$snake.dart'),
    );
    if (!entityFile.existsSync()) {
      _fail(
        'LEG A verify: canonical v5 entity file missing for $name — '
        'expected ${entityFile.path} (lib/src/domain/entities/$snake/'
        '$snake.dart).',
      );
    }
    final entitySrc = entityFile.readAsStringSync();
    if (!entitySrc.contains('@Zorphy(')) {
      _fail(
        'LEG A verify: $snake.dart is not a zfa-generated Zorphy entity '
        '(no @Zorphy annotation) — ${entityFile.path}.',
      );
    }
    for (final field in fields) {
      final getter =
          '${field['type'] as String} get ${field['name'] as String}';
      if (!entitySrc.contains(getter)) {
        _fail(
          'LEG A verify: entity $name is missing field getter '
          '"$getter" — ${entityFile.path}.',
        );
      }
    }

    // Codegen parts from `zfa build` (FR-004 compilation evidence).
    for (final part in ['$snake.zorphy.dart', '$snake.g.dart']) {
      final partFile = File(
        p.join(target, 'lib', 'src', 'domain', 'entities', snake, part),
      );
      if (!partFile.existsSync()) {
        _fail(
          'LEG A verify: generated part missing for $name — expected '
          '${partFile.path}.',
        );
      }
    }

    // Canonical v5 architecture files (US1-S3): repository, datasources,
    // usecases — the structure `zfa make` must land.
    final canonicalFiles = <String>[
      p.join(
        'lib',
        'src',
        'domain',
        'repositories',
        '${snake}_repository.dart',
      ),
      p.join(
        'lib',
        'src',
        'data',
        'repositories',
        'data_${snake}_repository.dart',
      ),
      p.join(
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_datasource.dart',
      ),
      p.join(
        'lib',
        'src',
        'data',
        'datasources',
        snake,
        '${snake}_remote_datasource.dart',
      ),
      p.join(
        'lib',
        'src',
        'domain',
        'usecases',
        snake,
        'get_${snake}_usecase.dart',
      ),
      p.join(
        'lib',
        'src',
        'domain',
        'usecases',
        snake,
        'update_${snake}_usecase.dart',
      ),
    ];
    for (final relative in canonicalFiles) {
      final file = File(p.join(target, relative));
      if (!file.existsSync()) {
        _fail(
          'LEG A verify: canonical v5 architecture file missing for '
          '$name — expected ${file.path}.',
        );
      }
    }
  }
  stdout.writeln(
    'LEG A verify OK: all ${entities.length} entities match the '
    'canonical v5 layout (entities + repositories + datasources + '
    'usecases + codegen parts).',
  );

  // Step 2 — STOP-AND-REPORT (FR-005): the protocol writes a structured
  // report beside the target and invokes NO rewrite command. The no-misfire
  // half is enforced structurally: this leg contains no `_runZfa` call
  // against the plain target at all.
  final reportFile = File(p.join(plainTarget, 'NOT-ZURAFFA-COMPATIBLE.md'));
  if (!reportFile.existsSync()) {
    _fail(
      'LEG B verify: structured report missing — expected '
      '${reportFile.path}. The stop-and-report protocol must leave a '
      'NOT-ZURAFFA-COMPATIBLE.md beside the target.',
    );
  }
  final reportSrc = reportFile.readAsStringSync();
  for (final section in <String>[
    '## Package',
    '## Verdict',
    '## Why it is not compatible',
    '## What would make it compatible',
  ]) {
    if (!reportSrc.contains(section)) {
      _fail(
        'LEG B verify: report ${reportFile.path} is missing required '
        'section "$section".',
      );
    }
  }
  // The verdict section must state the outcome and cite the doctor evidence.
  if (!reportSrc.contains('NOT Zuraffa-compatible')) {
    _fail(
      'LEG B verify: report verdict does not state '
      '"NOT Zuraffa-compatible".',
    );
  }
  if (!reportSrc.contains('Zuraffa package not found') ||
      !reportSrc.contains('zorphy_annotation not found')) {
    _fail(
      'LEG B verify: report "Why" section does not cite the doctor '
      'markers (Zuraffa package not found / zorphy_annotation not found).',
    );
  }
  // The remediation section must name the two concrete requirements.
  if (!reportSrc.contains('zuraffa') ||
      !reportSrc.contains('zorphy_annotation')) {
    _fail(
      'LEG B verify: report "What would make it compatible" section '
      'does not name the required zuraffa / zorphy_annotation deps.',
    );
  }

  // Step 3 — no-misfire proof (FR-005, US2-S1): the plain target's lib/
  // stays exactly as staged, and no v5 entity tree ever appears.
  final plainLib = Directory(p.join(plainTarget, 'lib'));
  final libEntries = plainLib.listSync().map((e) => p.basename(e.path)).toList()
    ..sort();
  if (libEntries.length != 1 || libEntries.first != 'main.dart') {
    _fail(
      'LEG B verify: the plain target lib/ was mutated during the '
      'exercise (expected only main.dart, found ${libEntries.join(', ')}) '
      '— the operator misfired and ran a generator against a '
      'non-Zuraffa package.',
    );
  }
  final leakedEntities = Directory(
    p.join(plainTarget, 'lib', 'src', 'domain', 'entities'),
  );
  if (leakedEntities.existsSync()) {
    _fail(
      'LEG B verify: a generated entity tree leaked into the plain '
      'target (${leakedEntities.path}) — the operator did not stop.',
    );
  }

  stdout.writeln(
    'LEG B verify OK: stop-and-report protocol observed — '
    'structured report present, no rewrite artifacts, lib/ pristine.',
  );
  stdout.writeln(
    'EXERCISE PASSED: agent-rewrite-zfa-only — compatible '
    'target rewritten zfa-only into canonical v5 layout; non-compatible '
    'target correctly stopped-and-reported.',
  );
  // Leave the sandbox in place so a downstream grader can inspect both
  // outcomes. Wiped on the next run.
  exit(0);
}

/// Compatibility assessment (FR-002): run `zfa doctor` in [pkgDir] and
/// classify the target from its published markers.
///
/// The verdict is derived from the doctor output text (doctor exits 0 in
/// both states — the signal is the markers, not the exit code).
Future<_CompatibilityVerdict> _detectCompatibility(String pkgDir) async {
  final result = await Process.run(
    'dart',
    [p.join(_zfaRoot, 'bin', 'zfa.dart'), 'doctor'],
    workingDirectory: pkgDir,
    runInShell: false,
  );
  final output = '${result.stdout as String}${result.stderr as String}';
  final compatible =
      output.contains('Zuraffa package found') &&
      output.contains('zorphy_annotation found');
  return _CompatibilityVerdict(compatible: compatible, output: output);
}

class _CompatibilityVerdict {
  _CompatibilityVerdict({required this.compatible, required this.output});

  /// True when the doctor surfaced the compatible markers.
  final bool compatible;

  /// Raw doctor output (stdout + stderr) for evidence in failure messages.
  final String output;
}

/// Outcome of one zfa CLI invocation.
class _ZfaRunResult {
  _ZfaRunResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;
}

/// Run the zfa CLI (this checkout's bin/zfa.dart) with [args] against the
/// package at [workingDir]. This is the ONLY way the rewrite leg mutates
/// the target — enforcing the zfa-only protocol (FR-008).
Future<_ZfaRunResult> _runZfa(String workingDir, List<String> args) async {
  final result = await Process.run(
    'dart',
    [p.join(_zfaRoot, 'bin', 'zfa.dart'), ...args],
    workingDirectory: workingDir,
    runInShell: false,
  );
  return _ZfaRunResult(
    exitCode: result.exitCode,
    output: '${result.stdout as String}${result.stderr as String}',
  );
}

/// Convert a PascalCase entity name to its canonical snake_case form
/// (`Note` -> `note`, the v5 directory/file segment).
String _snakeCase(String name) {
  final buf = StringBuffer();
  for (var i = 0; i < name.length; i += 1) {
    final ch = name[i];
    if (ch.toUpperCase() == ch && ch.toLowerCase() != ch && i > 0) {
      buf.write('_');
    }
    buf.write(ch.toLowerCase());
  }
  return buf.toString();
}

/// Render the structured stop-and-report artifact (FR-005, US2-S2): the
/// report a trained operator leaves when the target is not
/// Zuraffa-compatible — outcome, evidence, and remediation, so the caller
/// can act without re-running detection.
String _stopAndReport({
  required String packageName,
  required String packagePath,
  required String doctorOutput,
}) {
  final evidence = doctorOutput
      .split('\n')
      .where(
        (line) =>
            line.contains('Zuraffa package not found') ||
            line.contains('zorphy_annotation not found'),
      )
      .map((line) => '  - ${line.trim()}')
      .join('\n');
  return '''
# NOT Zuraffa-compatible: $packageName

Produced by the `agent-rewrite-zfa-only` GYM exercise (spec 021 / issue
#478) stop-and-report protocol. The rewrite was NOT attempted.

## Package

- name: `$packageName`
- path: `$packagePath`

## Verdict

NOT Zuraffa-compatible — the stop-and-report protocol fired; no `zfa`
rewrite command was run against this package.

## Why it is not compatible

`zfa doctor` surfaced the not-compatible markers:

$evidence

This package declares neither the `zuraffa` dependency nor
`zorphy_annotation`, so there is no Zuraffa marker to detect (no
`.zfa.json` config either). Running `zfa entity create` / `zfa make` /
`zfa build` here would misfire (issue #477): the commands refuse or
silently produce nothing useful.

## What would make it compatible

1. Add the Zuraffa runtime dependency: `dart pub add zuraffa` (or a path
   dependency on the local checkout).
2. Add the entity annotation dependency:
   `dart pub add zorphy_annotation`.
3. Re-run `zfa doctor` and confirm it reports
   `Zuraffa package found` + `zorphy_annotation found` before starting any
   rewrite.
''';
}

/// Recursively copy [src] directory to [dst].
Future<void> _copyTree(String src, String dst) async {
  await Directory(dst).create(recursive: true);
  final entities = Directory(src).listSync(recursive: false);
  for (final entity in entities) {
    final newPath = p.join(dst, p.basename(entity.path));
    if (entity is Directory) {
      await _copyTree(entity.path, newPath);
    } else if (entity is File) {
      await entity.copy(newPath);
    }
  }
}

/// Print a structured failure message and exit non-zero so the miki runner
/// records this exercise as failed.
void _fail(String message) {
  stderr.writeln('EXERCISE FAILED: agent-rewrite-zfa-only — $message');
  stderr.writeln('Mis-fire? Drop a card: github.com/arrrrny/drop-card');
  exit(1);
}
