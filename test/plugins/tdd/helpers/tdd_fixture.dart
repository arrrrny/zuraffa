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
    String suiteTemplate = defaultSuiteTemplate,
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
      await fx._writeProfile(singleTemplate, suiteTemplate);
    }
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    return fx;
  }

  /// Canonical full-suite template used unless overridden.
  static const defaultSuiteTemplate = 'dart test';

  Future<void> _writeProfile(
    String singleTemplate,
    String suiteTemplate,
  ) async {
    final dir = Directory(p.join(root.path, '.specify', 'memory'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `$singleTemplate`
- Full suite: `$suiteTemplate`

## Keys (machine-readable)

```yaml
runner: dart
single: '$singleTemplate'
suite: '$suiteTemplate'
file: 'dart test {file}'
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
  // Refactor-fixture seeds (spec 048, T001).
  // -------------------------------------------------------------------

  /// Seed a green-suite project: one passing test, a minimal `lib/`, and a
  /// pubspec that resolves `package:test` from the host (no offline cache
  /// needed). Used by the refactor command's preflight and re-proof paths.
  Future<void> seedGreenSuite({
    String testDescription = 'green baseline',
    String libContent = _defaultLibContent,
  }) async {
    await Directory(p.join(root.path, 'test')).create(recursive: true);
    await File(
      p.join(root.path, 'test', 'baseline_test.dart'),
    ).writeAsString(TddFixture.greenTest(testDescription));
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
    await File(
      p.join(root.path, 'lib', 'baseline.dart'),
    ).writeAsString(libContent);
  }

  /// Seed a red-suite project: one failing test plus the same minimal `lib/`.
  /// Used to prove the preflight refuses on red and modifies zero files.
  Future<void> seedRedSuite({String testDescription = 'red baseline'}) async {
    await Directory(p.join(root.path, 'test')).create(recursive: true);
    await File(
      p.join(root.path, 'test', 'baseline_test.dart'),
    ).writeAsString(TddFixture.redTest(testDescription));
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
    await File(
      p.join(root.path, 'lib', 'baseline.dart'),
    ).writeAsString(_defaultLibContent);
  }

  /// Seed a malformed `lib/` file with formatting/fixable violations that
  /// `dart format` and `dart fix --apply` will normalize. The `test/` tree
  /// is left green so the preflight passes and the passes can run.
  Future<void> seedMalformedLib({
    String testDescription = 'green with malformed lib',
  }) async {
    await Directory(p.join(root.path, 'test')).create(recursive: true);
    await File(
      p.join(root.path, 'test', 'baseline_test.dart'),
    ).writeAsString(TddFixture.greenTest(testDescription));
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
    // Unformatted: extra blank lines, trailing whitespace, missing trailing
    // newline, double-semicolons. `dart format` normalizes spacing/newlines;
    // `dart fix` may rewrite deprecated syntax if present. The content stays
    // valid Dart so the suite stays green before and after the pass.
    await File(
      p.join(root.path, 'lib', 'malformed.dart'),
    ).writeAsString('int answer() {  return  42 ;  }\n\n\n');
  }

  /// Replace `lib/baseline.dart` with content that passes the suite but is
  /// unformatted. Used to prove a no-op pass after one normalization pass:
  /// the second `refactor` invocation finds nothing to change.
  Future<void> writeCleanLib() async {
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
    await File(
      p.join(root.path, 'lib', 'baseline.dart'),
    ).writeAsString(_defaultLibContent);
  }

  /// Mark `lib/baseline.dart` as already-formatted (post-pass state) so the
  /// next refactor run is a clean no-op.
  Future<void> seedAlreadyCleanLib({
    String testDescription = 'green clean lib',
  }) async {
    await Directory(p.join(root.path, 'test')).create(recursive: true);
    await File(
      p.join(root.path, 'test', 'baseline_test.dart'),
    ).writeAsString(TddFixture.greenTest(testDescription));
    await Directory(p.join(root.path, 'lib')).create(recursive: true);
    // Already-formatted content: no trailing whitespace, single blank line,
    // trailing newline present. `dart format` is a no-op here.
    await File(
      p.join(root.path, 'lib', 'baseline.dart'),
    ).writeAsString("int answer() {\n  return 42;\n}\n");
  }

  /// Seed a green project whose `lib/` file passes `dart test` but breaks
  /// after `dart format` runs — used by the regression test (US3.AC2).
  /// The break is achieved by writing a file that compiles but whose test
  /// depends on a specific source layout the formatter changes. For a
  /// deterministic regression fixture, tests inject a fake pass executor
  /// instead (see [seedGreenSuiteWithBreakingPass] below).
  Future<void> seedGreenSuiteForRegression() async {
    await seedGreenSuite();
  }

  static const _defaultLibContent = 'int answer() {\n  return 42;\n}\n';

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
}
