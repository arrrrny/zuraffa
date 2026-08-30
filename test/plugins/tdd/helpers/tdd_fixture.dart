/// TddFixture — builds a throwaway Dart project carrying the TDD plugin's
/// file contracts (spec 046-tdd-verify-red, T001): a pubspec, the
/// `.specify/memory/tdd-profile.md` profile, a
/// `specs/<feature>/tdd/artifacts.json` registry, and synthetic test
/// files for each behavior kind.
///
/// Mirrors the `Directory.systemTemp` + `CliRunner(exitOnCompletion:
/// false)` conventions from `test/plugins/tdd/tdd_command_smoke_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A temp project with the registry/profile/test layout verify-red reads.
class TddFixture {
  TddFixture._(this.root, this.featureName, this._records);

  /// Project root (the temp directory itself).
  final Directory root;

  /// Feature directory name under `specs/`.
  final String featureName;

  final List<Map<String, dynamic>> _records;

  /// Canonical single-test template used unless overridden.
  static const defaultSingleTemplate = 'dart test {file} --plain-name "{name}"';

  static Future<TddFixture> create({
    String featureName = '090-tdd-fixture',
    String singleTemplate = defaultSingleTemplate,
    bool writeProfile = true,
  }) async {
    final root = Directory.systemTemp.createTempSync('tdd_fixture_');
    final fx = TddFixture._(root, featureName, <Map<String, dynamic>>[]);
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');
    if (writeProfile) {
      await fx._writeProfile(singleTemplate);
    }
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    return fx;
  }

  Future<void> _writeProfile(String singleTemplate) async {
    final dir = Directory(p.join(root.path, '.specify', 'memory'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `$singleTemplate`

## Keys (machine-readable)

```yaml
runner: dart
single: '$singleTemplate'
file: 'dart test {file}'
suite: 'dart test'
coverage: 'dart test --coverage'
```
''');
  }

  String get featureDir => p.join(root.path, 'specs', featureName);
  String get artifactsPath => p.join(featureDir, 'tdd', 'artifacts.json');
  String get cycleLogPath => p.join(featureDir, 'tdd', 'cycle-log.md');

  /// Absolute test path for a behavior id (default layout).
  String testPathOf(String id) =>
      p.join(root.path, 'test', '${_snake(id)}_test.dart');

  String _snake(String id) => id.toLowerCase().replaceAll('-', '_');

  /// Register a behavior: writes its test file (unless [writeTestFile] is
  /// false) and appends a gen-style record to the artifact registry.
  Future<void> registerBehavior({
    required String id,
    required String description,
    String sourceCriterion = 'FR-007',
    String? testContent,
    String? testPath,
    bool writeTestFile = true,
  }) async {
    final path = testPath ?? testPathOf(id);
    if (writeTestFile) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(testContent ?? _redTest(description));
    }
    _records.add({
      'behavior_id': id,
      'feature': featureName,
      'source_criterion': sourceCriterion,
      'test_path': path,
      'subject_path': p.join(root.path, 'lib', '${_snake(id)}_subject.dart'),
      'runnable_test_name': '$path::$id::$description',
      'test_ownership': 'created',
      'subject_ownership': 'created',
      'created_at': '2026-08-30T00:00:00.000Z',
    });
    await _flushRegistry();
  }

  /// Seed an existing red-evidence entry (for no-arg inference tests).
  Future<void> seedRedEvidence(String behaviorId) async {
    final file = File(cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (red)

- behavior: $behaviorId
- kind: red
- classification: assertionFailure
- criterion: FR-007
- test: ${testPathOf(behaviorId)}
- command: `dart test ${testPathOf(behaviorId)} --plain-name "x"`
- exit: 1
- at: 2026-08-30T00:00:00.000Z
- output:
```
Expected: <2>
```

''', mode: FileMode.append);
  }

  Future<void> _flushRegistry() async {
    await File(artifactsPath).parent.create(recursive: true);
    await File(
      artifactsPath,
    ).writeAsString(jsonEncode({'feature': featureName, 'records': _records}));
  }

  // -------------------------------------------------------------------
  // Test-content variants (the dishonest-red matrix).
  // -------------------------------------------------------------------

  static String _redTest(String description) =>
      '''
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(1, equals(2));
  });
}
''';

  static String redTest(String description) => _redTest(description);

  static String mutatingRedTest(String description) =>
      '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('$description', () {
    File('lib/verify_red_mutation.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('mutated');
    File('test/verify_red_mutation.txt').writeAsStringSync('mutated');
    expect(1, equals(2));
  });
}
''';

  static String greenTest(String description) =>
      '''
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(1, equals(1));
  });
}
''';

  static String skippedTest(String description) =>
      '''
import 'package:test/test.dart';

void main() {
  test('$description', () {}, skip: 'not ready');
}
''';

  static String compileErrorTest(String description) =>
      '''
import 'package:test/test.dart';

void main() {
  test('$description', () {
    undefinedFunctionHere();
  });
}
''';

  static String blendedTest(String description, String secondName) =>
      '''
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(1, equals(2));
  });
  test('$secondName', () {
    expect(1, equals(2));
  });
}
''';

  // -------------------------------------------------------------------
  // Integrity checks (SC-003: read-only over test/ and lib/).
  // -------------------------------------------------------------------

  /// Content fingerprint of every Dart file under `test/` and `lib/`,
  /// keyed by path. Exact for equality comparison.
  Map<String, String> checksumTestAndLib() {
    final sums = <String, String>{};
    for (final dirName in ['test', 'lib']) {
      final dir = Directory(p.join(root.path, dirName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          sums[entity.path] = _fingerprint(entity);
        }
      }
    }
    return sums;
  }

  static String _fingerprint(File file) {
    final bytes = file.readAsBytesSync();
    var h = bytes.length;
    for (final b in bytes) {
      h = (h * 31 + b) & 0x7fffffff;
    }
    return '${bytes.length}-$h';
  }

  /// Dispose the temp project.
  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  // -------------------------------------------------------------------
  // Spec 047-tdd-make extensions (T001): certified-red seed, fake zfa
  // script, and a sibling green test for regression scenarios.
  // -------------------------------------------------------------------

  /// Subject file path for a behavior id (mirrors `registerBehavior`'s
  /// subject_path layout).
  String subjectPathOf(String id) =>
      p.join(root.path, 'lib', '${_snake(id)}_subject.dart');

  /// Seed a complete certified-red behavior:
  ///   - a registry record,
  ///   - a cycle-log red entry (matching verify-red's contract),
  ///   - a failing assertion test on disk,
  ///   - a compiling stub subject (so `dart test` runs cleanly).
  ///
  /// This is the precondition `zfa tdd make <id>` requires.
  Future<void> seedCertifiedRed({
    required String id,
    String description = 'returns 42 when invoked with no args',
    String sourceCriterion = 'FR-007',
    String? testContent,
    String? subjectContent,
  }) async {
    // 1. Test file — an assertion that fails (the honest red).
    final testPath = testPathOf(id);
    await File(testPath).parent.create(recursive: true);
    await File(testPath).writeAsString(testContent ?? _redTest(description));

    // 2. Subject file — a compiling stub so the test compiles.
    final subjectPath = subjectPathOf(id);
    await File(subjectPath).parent.create(recursive: true);
    await File(subjectPath).writeAsString(subjectContent ?? _stubSubject(id));

    // 3. Registry record.
    _records.add({
      'behavior_id': id,
      'feature': featureName,
      'source_criterion': sourceCriterion,
      'test_path': testPath,
      'subject_path': subjectPath,
      'runnable_test_name': '$testPath::$id::$description',
      'test_ownership': 'created',
      'subject_ownership': 'created',
      'created_at': '2026-08-30T00:00:00.000Z',
    });
    await _flushRegistry();

    // 4. Cycle-log red entry (certified red).
    await seedRedEvidence(id);
  }

  /// A green sibling test (for regression-guard scenarios): the
  /// fixture's pipeline turns the target red green BUT breaks this
  /// sibling — the guard must surface it as a NEW failure.
  Future<String> seedSiblingGreenTest({
    required String id,
    String description = 'sibling green test passes',
  }) async {
    final path = testPathOf(id);
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString('''
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(1, equals(1));
  });
}
''');
    return path;
  }

  /// Write a fake `zfa` shell script to a directory under the fixture
  /// root and return its path. Tests pass this via `--zfa-bin` to
  /// drive the pipeline runner against a deterministic stub.
  ///
  /// The script logs every argv line to `<logPath>` and exits per
  /// [exitByArgv]: a map from a substring of the joined argv (e.g.
  /// `'build'`) to the exit code that invocation should produce.
  /// Defaults to exit 0 on every match. An optional
  /// [sideEffectByArgv] lets the script create / write files for
  /// tests that need the pipeline to actually mutate the project
  /// (e.g. turn the target test green by overwriting the subject).
  Future<String> writeFakeZfaBin({
    required String logPath,
    Map<String, int> exitByArgv = const {},
    Map<String, List<String>> sideEffectByArgv = const {},
  }) async {
    final binDir = Directory(p.join(root.path, 'fake_bin'));
    await binDir.create(recursive: true);
    final scriptPath = p.join(binDir.path, 'zfa');

    // Build a shell script. The log captures argv joined with a
    // separator so each invocation is one line. Side effects and
    // exit codes are matched via `[[ "$ARGV" == *"$pattern"* ]]`
    // so patterns containing spaces (e.g. `entity create`) match
    // as literals rather than glob-expanding into multiple tokens
    // (which produces a `syntax error near unexpected token`).
    final buf = StringBuffer()
      ..writeln('#!/usr/bin/env bash')
      ..writeln('set -e')
      ..writeln('LOG="$logPath"')
      ..writeln('ARGV="\$*"')
      ..writeln('echo "\$ARGV" >> "\$LOG"');
    if (sideEffectByArgv.isNotEmpty) {
      buf.writeln('# side-effect dispatch (substring match on argv)');
      sideEffectByArgv.forEach((pattern, commands) {
        buf.writeln('if [[ "\$ARGV" == *"$pattern"* ]]; then');
        for (final cmd in commands) {
          // NOTE: do not indent commands here — here-doc delimiters
          // must start at column 0 (or use `<<-` with tabs).
          buf.writeln(cmd);
        }
        buf.writeln('fi');
      });
    }
    if (exitByArgv.isNotEmpty) {
      buf.writeln('# exit-code dispatch (substring match on argv)');
      exitByArgv.forEach((pattern, code) {
        buf.writeln('if [[ "\$ARGV" == *"$pattern"* ]]; then');
        buf.writeln('exit $code');
        buf.writeln('fi');
      });
    }
    buf.writeln('exit 0');
    await File(scriptPath).writeAsString(buf.toString());
    await Process.run('chmod', ['+x', scriptPath]);
    return scriptPath;
  }

  /// Canonical stub subject used by [seedCertifiedRed]. Compiles
  /// cleanly so the target test's assertion failure is the only
  /// failure observed (matches the honest-red signature).
  static String _stubSubject(String id) =>
      '''
// Auto-generated stub subject for behavior $id.
// The `zfa tdd make` pipeline is responsible for the real implementation.
library;

int ${id.toLowerCase().replaceAll('-', '_')}_value() => 0;
''';

  /// Path to the fake zfa argv log written by [writeFakeZfaBin].
  String get fakeZfaLogPath => p.join(root.path, 'fake_bin', 'zfa_calls.log');

  /// Read the recorded fake-zfa argv lines (one per invocation).
  Future<List<String>> readFakeZfaLog() async {
    final file = File(fakeZfaLogPath);
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }
}
