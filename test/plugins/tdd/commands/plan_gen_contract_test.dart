// Bug #617 (tdd-plan-gen-test-list-format-mismatch) — the format contract.
//
// `zfa tdd plan` writes the CANONICAL 4-column test-list
// (`| id | behavior | traces | state |`, kind from the section header);
// `zfa tdd gen` must resolve those rows through the SHARED
// `TestListReader`. Before the fix gen carried a private 6-column parser
// (`parts.length >= 7` / `cells.length >= 6`) that silently skipped every
// 4-column row, so every behavior planned by plan was "unknown" to gen and
// `zfa tdd run` stopped at its first step (`A1:gen`, unknown behavior id).
//
// These tests pin the round trip plan → gen in both loop sections plus the
// target-defaulting behavior that moved from gen's parser into the shared
// reader. The slow-tier loop e2e (plan → run → DONE on a real temp
// project) lives in scenarios/sc_018_plan_run_loop_e2e_test.dart.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '001-demo';

  List<String> args(List<String> rest) => [
    'tdd',
    ...rest,
    '--project',
    tmpDir.path,
  ];

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('plan_gen_contract_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 001-demo

## Functional Requirements

- **FR-001**: returns 42 when invoked with no args

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks for the answer **Then** returns 42 when invoked with no args
''');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args(['plan', featureName]));
  }

  Future<String> runGen(String id) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args(['gen', id]));
  }

  test('plan writes the canonical 4-column test list', () async {
    await runPlan();

    final list = File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).readAsStringSync();
    // The canonical shape: 4 columns, both loop sections. (plan reports
    // via stdout.writeln, which the CliRunner zone does not capture — the
    // file is the contract, so assert on it.)
    expect(list, contains('| id | behavior | traces | state |'));
    expect(list, isNot(contains('kind')));
    expect(list, contains('## Outer loop: acceptance behaviors'));
    expect(list, contains('## Inner loop: unit behaviors'));
  });

  test(
    'BUG #617 RED: gen resolves an acceptance behavior planned by plan',
    () async {
      await runPlan();
      final out = await runGen('A1');

      expect(out, contains('behavior_id: A1'), reason: 'out:\n$out');
      expect(out, contains('source_criterion: AC-1'));
      expect(
        File(
          p.join(tmpDir.path, 'test', 'tdd', featureName, 'a1_test.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(tmpDir.path, 'lib', 'tdd', featureName, 'a1_subject.dart'),
        ).existsSync(),
        isTrue,
      );
      final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(regFile.existsSync(), isTrue);
    },
  );

  test('BUG #617 RED: gen resolves a unit behavior planned by plan', () async {
    await runPlan();
    final out = await runGen('U1');

    expect(out, contains('behavior_id: U1'), reason: 'out:\n$out');
    expect(out, contains('source_criterion: FR-001'));
    expect(
      File(
        p.join(tmpDir.path, 'test', 'tdd', featureName, 'u1_test.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(tmpDir.path, 'lib', 'tdd', featureName, 'u1_subject.dart'),
      ).existsSync(),
      isTrue,
    );
  });

  test('kind derives from the plan section, not from a kind column', () async {
    await runPlan();
    await runGen('A1');
    await runGen('U1');

    final acceptanceTest = File(
      p.join(tmpDir.path, 'test', 'tdd', featureName, 'a1_test.dart'),
    ).readAsStringSync();
    expect(acceptanceTest, contains('// kind: acceptance'));
    final unitTest = File(
      p.join(tmpDir.path, 'test', 'tdd', featureName, 'u1_test.dart'),
    ).readAsStringSync();
    expect(unitTest, contains('// kind: unit'));
  });

  test('target defaults to subject_<snake-id> for plan-written rows', () async {
    await runPlan();
    await runGen('A1');
    await runGen('U1');

    // The defaulting logic moved from gen's private parser into the shared
    // reader: a row with no target cell resolves to `subject_<snake-id>`,
    // and the subject stub renders that function name.
    final acceptanceSubject = File(
      p.join(tmpDir.path, 'lib', 'tdd', featureName, 'a1_subject.dart'),
    ).readAsStringSync();
    expect(acceptanceSubject, contains('subject_a1'));
    final unitSubject = File(
      p.join(tmpDir.path, 'lib', 'tdd', featureName, 'u1_subject.dart'),
    ).readAsStringSync();
    expect(unitSubject, contains('subject_u1'));
  });

  test(
    'a description with a number is asserted by the generated test',
    () async {
      await runPlan();
      await runGen('U1');

      final unitTest = File(
        p.join(tmpDir.path, 'test', 'tdd', featureName, 'u1_test.dart'),
      ).readAsStringSync();
      // The behavior description "returns 42 when invoked with no args" is
      // carried into the test's assertion — proof the description column
      // survived the shared reader end to end.
      expect(unitTest, contains('equals(42)'));
    },
  );

  // -------------------------------------------------------------------
  // Spec 050 (FR-007) — the migration completion for bug #617: the
  // repo's own hand-written lists (specs/044–049) use the tdd
  // extension's 6-column dialect, whose kind cell names the test SHAPE
  // (`example`), not the loop. The shim must read them: kind from the
  // section header, test-reference cell -> default target.
  // -------------------------------------------------------------------

  test('A4/050: gen resolves an id from a hand-written 6-column '
      'extension-dialect list (the 046/049 shape)', () async {
    final legacyDir = p.join(tmpDir.path, 'specs', '050-legacy');
    await Directory(p.join(legacyDir, 'tdd')).create(recursive: true);
    await File(p.join(legacyDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: 050-legacy

## Outer loop: acceptance behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | Honestly-red behavior run: classification `assertion`, red entry appended, exit 0 | US1.AC1 | example | DONE | sc_001_certifies_honest_red_test.dart::A1 |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Parses 4-column rows in list order | FR-001 | example | DONE | test_list_reader_test.dart::U1 |
''');

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'gen',
      'A1',
      '--feature',
      '050-legacy',
      '--project',
      tmpDir.path,
    ]);

    expect(out, contains('behavior_id: A1'), reason: 'out:\n$out');
    expect(out, contains('source_criterion: US1.AC1'));
    expect(out, contains('ownership: created/created'));
    expect(
      File(
        p.join(tmpDir.path, 'test', 'tdd', '050-legacy', 'a1_test.dart'),
      ).existsSync(),
      isTrue,
    );
    // The test-reference cell is path-like -> the default target
    // (FR-003), rendered in the subject stub.
    final subject = File(
      p.join(tmpDir.path, 'lib', 'tdd', '050-legacy', 'a1_subject.dart'),
    ).readAsStringSync();
    expect(subject, contains('subject_a1'));
  });

  group('bug 829: plan extracts the spec Key Entities into the test list', () {
    test('a spec with a Key Entities section yields the entities table; '
        'the behavior rows are unchanged', () async {
      await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: 001-demo

## Functional Requirements

- **FR-001**: The system shall persist a User with a name and an email.

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks for the answer **Then** returns 42 when invoked with no args

### Key Entities

- **User**: The domain entity for stored users. Contains `name: String`, `email: String`.
''');
      await runPlan();

      final list = File(
        p.join(featureDir, 'tdd', 'test-list.md'),
      ).readAsStringSync();
      expect(list, contains('## Key entities'));
      expect(list, contains('| User | name: String, email: String |'));
      // The behavior rows keep the canonical 4-column shape.
      expect(list, contains('| U1 | The system shall persist a User'));
    });

    test('a spec without Key Entities writes no entities section '
        '(pre-829 lists are byte-identical in shape)', () async {
      await runPlan();

      final list = File(
        p.join(featureDir, 'tdd', 'test-list.md'),
      ).readAsStringSync();
      expect(list, isNot(contains('## Key entities')));
    });
  });
}
