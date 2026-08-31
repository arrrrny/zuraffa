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
    await File(p.join(root.path, 'bin', 'zfa.dart'))
        .create(recursive: true)
        .then((file) => file.writeAsString('void main() {}\n'));
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

  /// Content fingerprint of every regular file under `test/` and `lib/`,
  /// keyed by path. Exact for equality comparison.
  Map<String, String> checksumTestAndLib() {
    final sums = <String, String>{};
    for (final dirName in ['test', 'lib']) {
      final dir = Directory(p.join(root.path, dirName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          sums[entity.path] = _fingerprint(entity);
        }
      }
    }
    return sums;
  }

  /// Content fingerprint of the complete `test/` tree, including
  /// non-Dart files and directory entries. Added, removed, or modified
  /// content changes the returned map.
  Map<String, String> checksumTestTree() {
    final testRoot = Directory(p.join(root.path, 'test'));
    if (!testRoot.existsSync()) return const {};
    final sums = <String, String>{};
    for (final entity in testRoot.listSync(recursive: true)) {
      final relative = p.relative(entity.path, from: testRoot.path);
      if (entity is Directory) {
        sums['$relative/'] = 'directory';
      } else if (entity is File) {
        sums[relative] = _fingerprint(entity);
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

  // -------------------------------------------------------------------
  // 049-tdd-run extensions: run-state/test-list seeding, green evidence,
  // and a scripted fake zfa step binary.
  // -------------------------------------------------------------------

  /// Path of the feature's `tdd/run-state.json`.
  String get runStatePath => p.join(featureDir, 'tdd', 'run-state.json');

  /// Path of the feature's `tdd/test-list.md`.
  String get testListPath => p.join(featureDir, 'tdd', 'test-list.md');

  /// Directory holding the scripted fake zfa binary, its config files and
  /// its invocation log.
  String get fakeZfaDir => p.join(root.path, '.fake-zfa');

  /// The fake zfa entrypoint passed to the driver via `--zfa-bin`.
  String get fakeZfaBin => p.join(fakeZfaDir, 'zfa');

  /// Render one 4-column test-list section in the format
  /// `plan_command.dart` writes.
  static String _renderTestListSection(
    String title,
    List<(String, String, String, String)> rows,
  ) {
    final buf = StringBuffer()
      ..writeln('## $title')
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final (id, description, traces, state) in rows) {
      buf.writeln('| $id | $description | $traces | $state |');
    }
    buf.writeln();
    return buf.toString();
  }

  /// Seed `specs/<feature>/tdd/test-list.md` in the 4-column format
  /// `plan_command.dart` writes. Rows carrying `kind: 'acceptance'` land in
  /// the outer-loop section, everything else in the inner-loop section.
  Future<void> seedTestList(
    List<
      ({
        String id,
        String description,
        String traces,
        String state,
        String kind,
      })
    >
    rows,
  ) async {
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    final acceptance = rows
        .where((r) => r.kind == 'acceptance')
        .map((r) => (r.id, r.description, r.traces, r.state))
        .toList();
    final unit = rows
        .where((r) => r.kind != 'acceptance')
        .map((r) => (r.id, r.description, r.traces, r.state))
        .toList();
    final buf = StringBuffer()
      ..writeln('# Test List: $featureName')
      ..writeln();
    if (acceptance.isNotEmpty) {
      buf.write(
        _renderTestListSection('Outer loop: acceptance behaviors', acceptance),
      );
    }
    if (unit.isNotEmpty) {
      buf.write(_renderTestListSection('Inner loop: unit behaviors', unit));
    }
    await File(testListPath).writeAsString(buf.toString());
  }

  /// Seed `tdd/run-state.json` (the shape `RunStateStore` reads/writes).
  Future<void> seedRunState({
    required Map<String, String> states,
    String? inFlightBehaviorId,
    String? inFlightStep,
    int? inFlightOwnerPid,
  }) async {
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(runStatePath).writeAsString(
      jsonEncode({
        'feature': featureName,
        'behavior_states': states,
        'in_flight_behavior_id': ?inFlightBehaviorId,
        'in_flight_step': ?inFlightStep,
        'in_flight_owner_pid': ?inFlightOwnerPid,
      }),
    );
  }

  /// Seed a green-evidence entry for [behaviorId] (mirrors [seedRedEvidence]).
  Future<void> seedGreenEvidence(String behaviorId) async {
    final file = File(cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- criterion: FR-003
- test: ${testPathOf(behaviorId)}
- exit: 0
- at: 2026-08-30T00:00:00.000Z

''', mode: FileMode.append);
  }

  /// Write the scripted fake zfa binary (a POSIX shell script) plus its
  /// empty config directory and invocation log.
  ///
  /// The fake receives the driver's step argv
  /// `tdd <step> <id> --feature <f> --project <dir>`, appends
  /// `<step> <id>` to the invocation log, and behaves per the config file
  /// `config/<step>-<id>` when present (`ok` by default):
  ///
  /// - `ok` — success summary line, exit 0, evidence appended to the
  ///   feature's cycle log (red for verify-red, green for make);
  /// - `ok-no-evidence` — success summary + exit 0, no evidence written
  ///   (drives the driver's evidence misfire path);
  /// - `exit0:<outcome>` — prints `<outcome>`, exit 0 (contract-inconsistent
  ///   success that the driver must reject);
  /// - any other token — printed as the step's outcome/classification,
  ///   exit 1 (a named step failure).
  Future<void> writeFakeZfa() async {
    await Directory(fakeZfaDir).create(recursive: true);
    final configDir = p.join(fakeZfaDir, 'config');
    await Directory(configDir).create(recursive: true);
    final logPath = p.join(fakeZfaDir, 'log');
    await File(logPath).writeAsString('');

    const script = r'''#!/bin/sh
# Fake zfa CLI for `zfa tdd run` driver tests (spec 049-tdd-run).
# argv: tdd <step> <behavior-id> --feature <f> --project <dir>
STEP="$2"
ID="$3"
FEATURE=""
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done
echo "$STEP $ID" >> "__LOG__"
CFG="__CFG__/$STEP-$ID"
if [ -f "$CFG" ]; then
  # Multi-line configs script attempts in order: the first invocation of
  # this (step, id) consumes line 1; every later invocation consumes the
  # last line (bug #625 deferred-make re-attempts).
  ATTEMPTS=$(grep -c "^$STEP $ID\$" "__LOG__")
  if [ "$ATTEMPTS" -le 1 ]; then
    OUTCOME=$(head -n 1 "$CFG")
  else
    OUTCOME=$(tail -n 1 "$CFG")
  fi
else
  OUTCOME="ok"
fi
CYCLE="$PROJECT/specs/$FEATURE/tdd/cycle-log.md"
case "$STEP" in
  gen)
    case "$OUTCOME" in
      ok) exit 0 ;;
      exit0:*) echo "gen: behavior=$ID outcome=${OUTCOME#exit0:}"; exit 0 ;;
      *) echo "zfa tdd gen: $OUTCOME"; exit 1 ;;
    esac
    ;;
  verify-red)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-003\n- exit: 1\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
        echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
        exit 0
        ;;
      ok-no-evidence)
        echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
        exit 0
        ;;
      exit0:*)
        echo "verify-red: behavior=$ID classification=${OUTCOME#exit0:} certified=true feature=$FEATURE"
        exit 0
        ;;
      *)
        echo "verify-red: behavior=$ID classification=$OUTCOME certified=false feature=$FEATURE"
        exit 1
        ;;
    esac
    ;;
  make)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-003\n- exit: 0\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
        echo "make: behavior=$ID outcome=green feature=$FEATURE"
        exit 0
        ;;
      ok-no-evidence)
        echo "make: behavior=$ID outcome=green feature=$FEATURE"
        exit 0
        ;;
      exit0:*)
        echo "make: behavior=$ID outcome=${OUTCOME#exit0:} feature=$FEATURE"
        exit 0
        ;;
      *)
        echo "make: behavior=$ID outcome=$OUTCOME feature=$FEATURE"
        exit 1
        ;;
    esac
    ;;
  refactor)
    case "$OUTCOME" in
      ok) echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"; exit 0 ;;
      exit0:*) echo "refactor: behavior=$ID outcome=${OUTCOME#exit0:} feature=$FEATURE"; exit 0 ;;
      *) echo "refactor: behavior=$ID outcome=$OUTCOME feature=$FEATURE"; exit 1 ;;
    esac
    ;;
  *)
    echo "zfa tdd $STEP: unknown step"
    exit 1
    ;;
esac
''';
    await File(fakeZfaBin).writeAsString(
      script.replaceAll('__LOG__', logPath).replaceAll('__CFG__', configDir),
    );
    Process.runSync('chmod', ['+x', fakeZfaBin]);
  }

  /// Script the fake step's outcome for one (step, behavior) pair.
  ///
  /// A single-line [outcome] applies to every attempt. A multi-line
  /// outcome scripts attempts in order: the first invocation consumes
  /// line 1, every subsequent invocation consumes the LAST line (bug
  /// #625: a deferred acceptance make can fail `unexpressible` on its
  /// phase-1 attempt and report green when phase 2 re-attempts it).
  Future<void> setStepOutcome(String step, String id, String outcome) async {
    await Directory(p.join(fakeZfaDir, 'config')).create(recursive: true);
    await File(
      p.join(fakeZfaDir, 'config', '$step-$id'),
    ).writeAsString(outcome);
  }

  /// The fake's invocation log: one `<step> <id>` line per step spawn.
  List<String> stepInvocations() {
    final file = File(p.join(fakeZfaDir, 'log'));
    if (!file.existsSync()) return const [];
    return file
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Truncate the fake's invocation log (between runs in a test).
  void clearStepInvocations() {
    File(p.join(fakeZfaDir, 'log')).writeAsStringSync('');
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

  /// Test content whose result depends on the generated production subject.
  static String subjectDrivenTest(
    String id,
    String description, {
    int expected = 42,
  }) {
    final symbol = id.toLowerCase().replaceAll('-', '_');
    return '''
import '../lib/${symbol}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(${symbol}_value(), equals($expected));
  });
}
''';
  }

  /// Generated subject content used by fake-pipeline source mutations.
  static String subjectReturning(String id, int value) {
    final symbol = id.toLowerCase().replaceAll('-', '_');
    return '''
library;

int ${symbol}_value() => $value;
''';
  }

  /// Shell commands for a fake-zfa step to replace a production subject.
  List<String> overwriteSubjectCommands(String id, String content) => [
    'cat > "${subjectPathOf(id)}" <<\'ZFA_EOF\'',
    content,
    'ZFA_EOF',
  ];

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
    await File(
      path,
    ).writeAsString(subjectDrivenTest(id, description, expected: 1));
    final subject = File(subjectPathOf(id));
    await subject.parent.create(recursive: true);
    await subject.writeAsString(subjectReturning(id, 1));
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
