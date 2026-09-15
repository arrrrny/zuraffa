// The no-JIT zfa spawn sweep (the compiled-child policy).
//
// Policy: NOTHING spawns the zfa CLI in JIT mode. Every `.dart` entrypoint is
// AOT compiled once through `ZfaExecutable.ensureCompiled` and the artifact is
// spawned alone; `dart <script>` survives only under the explicit
// `ZFA_ALLOW_JIT=1` escape hatch. The pre-policy shapes this test hunts:
//
//   1. `entry.endsWith('.dart') ? ['dart', entry, ...argv] : [entry, ...argv]`
//      (step_runner.dart:377, corpus_step_runner.dart:161,
//      run_driver_core.dart:3463, refactor_passes.dart:551/587/672,
//      dream_runner.dart:655);
//   2. an argv list that starts with the bare `dart` program and then names a
//      zfa entrypoint (differential_ref_runner.dart:242 before the fix);
//   3. any argv starting with a bare `dart` inside a REGISTERED zfa spawn site
//      whose next token is not a Dart-toolchain subcommand (`dart pub get`,
//      `dart test`, `dart analyze`, …).
//
// The scan is textual on purpose: it is a drift tripwire, not a compiler.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const String repoRoot = '.';

/// The one file allowed to shape a `dart …` zfa child: the policy's own
/// service, where `ensureCompiled` compiles and `commandFor` gates the `dart`
/// prefix behind the escape hatch. Every other lib/src file must go through
/// it.
const String kServiceFile = 'lib/src/cli/zfa_executable.dart';

/// Every site that spawns a zfa child, with the reason it is on the list.
/// A new site MUST be added here — the sweep asserts each resolves its child
/// through the service (`ensureCompiled`).
const Map<String, String> kSpawnSites = {
  'lib/src/plugins/tdd/services/step_runner.dart':
      'TDD step children (gen / verify-red / make / refactor, spec 049)',
  'lib/src/plugins/tdd/services/corpus_step_runner.dart':
      'corpus harness children (tdd run / tdd verify, spec 051)',
  'lib/src/plugins/tdd/services/pipeline_runner.dart':
      'make pipeline children (generation plan steps, spec 047)',
  'lib/src/plugins/tdd/services/refactor_passes.dart':
      'the refactor build pass (bug #689 / issue #1472)',
  'lib/src/plugins/tdd/services/dream_runner.dart': 'dream-runner zfa children',
  'lib/src/plugins/tdd/services/differential_ref_runner.dart':
      'differential ref worktree children (bug #805)',
  'lib/src/plugins/tdd/services/replay_runner.dart':
      'replayed recorded zfa commands (spec 0806)',
  'lib/src/plugins/tdd/commands/run_driver_core.dart':
      'phase-0 entity orchestration (bug #829)',
};

/// The registered sites that shape their child argv through
/// `ZfaExecutable.commandFor`. The two sites NOT listed here spawn the
/// artifact `ensureCompiled` returned directly, so they have no argv to
/// shape: `pipeline_runner` runs `entrypoint.executable`, and
/// `replay_runner` re-anchors recorded command STRINGS onto the compiled
/// path. A site may only leave this set together with that direct spawn.
const Set<String> kArgvShapingSites = {
  'lib/src/plugins/tdd/services/step_runner.dart',
  'lib/src/plugins/tdd/services/corpus_step_runner.dart',
  'lib/src/plugins/tdd/services/refactor_passes.dart',
  'lib/src/plugins/tdd/services/dream_runner.dart',
  'lib/src/plugins/tdd/services/differential_ref_runner.dart',
  'lib/src/plugins/tdd/commands/run_driver_core.dart',
};

/// The Dart-toolchain subcommands a spawn-site argv may legitimately name.
/// Anything else after a bare `dart` program in those files is another CLI
/// being run through the VM — which for zfa is exactly what the policy bans.
const Set<String> kToolchainSubcommands = {
  'pub',
  'run',
  'test',
  'compile',
  'analyze',
  'format',
  'fix',
  'dartdev',
};

List<File> _dartFilesUnder(String dir) {
  final dirEntity = Directory(p.join(repoRoot, dir));
  if (!dirEntity.existsSync()) return const [];
  return dirEntity
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// A reference to the service's compile seam — a call, a tear-off, or the
/// default of an injected `ZfaEnsureCompiled` alias (`refactor_passes` and
/// `pipeline_runner` bind it to a local `compile`). Strictly stronger than
/// the old `contains('ensureCompiled')`: a comment, an unused import or a
/// parameter name alone no longer satisfies the sweep.
final RegExp _ensureCompiledSeam = RegExp(r'ZfaExecutable\.ensureCompiled\b');

/// A CALL of the argv-shaping seam (`ensureCompiled` + this pairing is what
/// makes a spawn site actually route its child through the service).
final RegExp _commandForCall = RegExp(r'ZfaExecutable\.commandFor\s*\(');

/// Normalizes a path to the repo-root-relative POSIX form (strips a leading
/// `./`, backslashes to slashes) so set membership checks are stable across
/// `dart test` invocation styles.
String _normalized(String path) {
  var rel = path.replaceAll('\\', '/');
  while (rel.startsWith('./')) {
    rel = rel.substring(2);
  }
  return rel;
}

/// The explicit escape hatch (or its constant) appears in [window] — the one
/// documented reason a `dart`-prefixed zfa argv may exist.
bool _isEnvGated(String window) =>
    window.contains('kZfaAllowJitEnv') || window.contains('ZFA_ALLOW_JIT');

/// A window naming a zfa entrypoint (or the variable a spawn site keeps it
/// in) — what makes a `['dart', …]` argv a zfa spawn rather than a toolchain
/// call.
bool _mentionsZfaEntry(String window) =>
    window.contains('zfa.dart') ||
    window.contains('zuraffa.dart') ||
    window.contains('zfaBin') ||
    window.contains('zfaExe') ||
    window.contains('worktreeBin') ||
    window.contains('entrypoint') ||
    window.contains('compiledEntry');

/// Rule 1: `endsWith('.dart')` deciding an argv that carries a `'dart'`
/// program — the ternary every rewired site used to have.
bool _hasDartTernary(String source) {
  final pattern = RegExp(r'''endsWith\(\s*['"]\.dart['"]\s*\)''');
  for (final match in pattern.allMatches(source)) {
    final window = source.substring(
      match.start,
      (match.end + 220).clamp(0, source.length),
    );
    if (!window.contains("'dart'") && !window.contains('"dart"')) continue;
    if (_isEnvGated(window)) continue;
    return true;
  }
  return false;
}

/// Rule 2: `['dart', <zfa entrypoint> …]` — the bare VM program followed by
/// an entrypoint token.
bool _hasDartEntrypointArgv(String source) {
  final pattern = RegExp(r"\[\s*'dart'\s*,");
  for (final match in pattern.allMatches(source)) {
    final window = source.substring(
      match.start,
      (match.end + 300).clamp(0, source.length),
    );
    if (!_mentionsZfaEntry(window)) continue;
    if (_isEnvGated(window)) continue;
    return true;
  }
  return false;
}

/// Rule 3: inside a registered spawn site, a `['dart', …]` argv whose first
/// argument is not a Dart-toolchain subcommand.
List<String> _nonToolchainDartArgvs(String source) {
  final offenders = <String>[];
  final pattern = RegExp(r"\[\s*'dart'\s*,\s*'?([A-Za-z_]+)'?");
  for (final match in pattern.allMatches(source)) {
    final subcommand = match.group(1)!;
    if (kToolchainSubcommands.contains(subcommand)) continue;
    offenders.add(match.group(0)!);
  }
  return offenders;
}

void main() {
  group('no-JIT zfa spawn sweep', () {
    test('the detectors fire on the pre-policy shapes (positive controls)', () {
      // Without these, a detector that silently stopped matching after a
      // refactor would leave every sweep below green with no signal at all.
      expect(
        _hasDartTernary("final c = e.endsWith('.dart') ? ['dart', e] : [e];"),
        isTrue,
      );
      expect(
        _hasDartEntrypointArgv("final c = ['dart', zfaBin, 'tdd'];"),
        isTrue,
      );
      expect(_nonToolchainDartArgvs("final c = ['dart', zfaExe, 'tdd'];"), [
        "['dart', zfaExe",
      ]);
      expect(
        _nonToolchainDartArgvs("final c = ['dart', 'test', 'x'];"),
        isEmpty,
        reason: 'a toolchain call is not an offender',
      );
    });

    test('no lib/src file shapes a `dart <zfa entry>` child argv', () {
      final scanned = _dartFilesUnder('lib/src');
      // A sweep over an empty set passes vacuously: if `lib/src` is ever
      // renamed, or the test runs from another working directory, fail
      // loudly instead of going green without reading a single file.
      expect(scanned, isNotEmpty, reason: 'the sweep read no file at all');
      final offenders = <String>[];
      for (final file in scanned) {
        final rel = _normalized(file.path);
        if (rel == kServiceFile) continue;
        final source = file.readAsStringSync();
        if (_hasDartTernary(source) || _hasDartEntrypointArgv(source)) {
          offenders.add(rel);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'every zfa child must be a COMPILED binary: resolve the '
            'entrypoint through ZfaExecutable.ensureCompiled and shape the '
            'argv through ZfaExecutable.commandFor ($kServiceFile). '
            'Offenders: $offenders',
      );
    });

    test('registered spawn sites never run a non-toolchain program through '
        'the Dart VM', () {
      final offenders = <String>[];
      for (final site in kSpawnSites.keys) {
        final file = File(p.join(repoRoot, site));
        if (!file.existsSync()) {
          offenders.add('$site (missing)');
          continue;
        }
        for (final argv in _nonToolchainDartArgvs(file.readAsStringSync())) {
          offenders.add('$site: $argv');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a spawn site may only run the Dart TOOLCHAIN through the VM '
            '(dart pub get / dart test / …); a zfa child goes through the '
            'compiled artifact. Offenders: $offenders',
      );
    });

    test('every registered spawn site resolves its child through the '
        'service', () {
      expect(kSpawnSites, isNotEmpty, reason: 'the registry is empty');
      final missing = <String>[];
      for (final entry in kSpawnSites.entries) {
        final file = File(p.join(repoRoot, entry.key));
        if (!file.existsSync()) {
          missing.add('${entry.key} (missing)');
          continue;
        }
        final source = file.readAsStringSync();
        // A reference to the seam, not a mention: an unused import, a
        // comment or a doc reference used to satisfy the old substring
        // check while the site still spawned a raw command.
        if (!_ensureCompiledSeam.hasMatch(source)) {
          missing.add('${entry.key} (${entry.value})');
          continue;
        }
        if (kArgvShapingSites.contains(entry.key) &&
            !_commandForCall.hasMatch(source)) {
          missing.add(
            '${entry.key} (argv not shaped through ZfaExecutable.commandFor)',
          );
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'every zfa spawn site must reference the $kServiceFile seam '
            '(ZfaExecutable.ensureCompiled) and, where it shapes an argv, '
            'shape it through ZfaExecutable.commandFor. Missing: $missing',
      );
    });

    test('the ZFA_ALLOW_JIT escape hatch is read only by the service', () {
      final scanned = _dartFilesUnder('lib/src');
      expect(scanned, isNotEmpty, reason: 'the sweep read no file at all');
      final offenders = <String>[];
      for (final file in scanned) {
        final rel = _normalized(file.path);
        if (rel == kServiceFile) continue;
        final source = file.readAsStringSync();
        if (source.contains("'ZFA_ALLOW_JIT'") ||
            source.contains('kZfaAllowJitEnv')) {
          offenders.add(rel);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the escape hatch must stay a single, auditable read in '
            '$kServiceFile. Offenders: $offenders',
      );
    });
  });
}
