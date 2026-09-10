// Issue #1310 — the plan→gen declared-signature path is unreachable:
// `zfa tdd plan` writes only the criterion id (FR-001) into the
// test-list / lane-plan traces cell, while
// `DeclaredRouting.declaredSignatureFor` (the #1259 remediation) needs
// the cell to carry the traced contract row names — its doc comment
// says the cell is "a raw string (`FR-001, Formatter.format`)".
// With a criterion-only cell the resolver resolves zero contract rows,
// gen falls back to the legacy guard-only pair, and make dead-ends on
// vacuous-green.
//
// Behavior map (specs/1277-plan-traces-cell-contract-names):
//   U1 — the legacy single-file plan's unit row cell carries the full
//        trace set: criterion + contract references.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The issue's repro spec: FR-001 traces to the declared DOMAIN row
/// `TodoRepository` (method-qualified: `TodoRepository.create`) whose
/// declared signature is `create(String title) -> bool`.
const reproSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title
            traces: TodoRepository.create

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';

/// The same spec minus the `traces:` continuation — the fallback shape
/// whose cells must stay criterion-only (acceptance criterion 4).
const untracedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';

/// A spec declaring `## Lanes` so the plan splits into the lane files —
/// the acceptance-criterion-3 shape.
const lanedSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
```

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title
            traces: TodoRepository.create

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';

/// Plan [specMd] into a temp project and return stdout plus the raw
/// test-list content (and the 04-ENGINE content when the lane split
/// produced one).
Future<({String out, String testList, String engine})> planSpec(
  String specMd,
) async {
  final tmp = Directory.systemTemp.createTempSync('issue_1310_');
  try {
    final featureDir = p.join(tmp.path, 'specs', '1310-repro');
    await Directory(featureDir).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(specMd);
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'plan',
      '1310-repro',
      '--project',
      tmp.path,
    ]);
    final testList = await File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).readAsString();
    final engineFile = File(p.join(featureDir, 'tdd', '04-ENGINE.md'));
    final engine = engineFile.existsSync()
        ? await engineFile.readAsString()
        : '';
    return (out: out, testList: testList, engine: engine);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// The unit row line for [id] out of a rendered test list / lane plan.
String? unitRowOf(String rendered, String id) => rendered
    .split('\n')
    .where((line) => line.startsWith('| $id |'))
    .firstOrNull;

/// Gen writes its artifacts namespaced by feature slug (bug #827); the
/// registry record is the single path contract, so the tests read
/// through it.
Future<String> genSubjectOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(fixturePath(fx, record['subject_path'] as String)).readAsString();
}

Future<String> genTestOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(fixturePath(fx, record['test_path'] as String)).readAsString();
}

String fixturePath(TddFixture fx, String recordedPath) =>
    p.isAbsolute(recordedPath)
    ? recordedPath
    : p.join(fx.root.path, recordedPath);

void main() {
  group('issue #1310 — plan writes the full trace set into traces cells', () {
    test('U1: the legacy single-file plan unit cell carries the criterion '
        'id plus the contract reference', () async {
      final (:out, testList: list, engine: _) = await planSpec(reproSpec);
      expect(exitCode, 0, reason: 'plan must succeed: $out');
      final row = unitRowOf(list, 'U1');
      expect(row, isNotNull, reason: 'the plan must derive U1:\n$list');
      expect(
        row,
        contains('FR-001, TodoRepository.create'),
        reason:
            'the traces cell must carry the full trace set — criterion id '
            '+ method-qualified contract reference (issue #1310):\n$list',
      );
    });

    test('U2: the lane plan (04-ENGINE.md) unit cell carries the same '
        'full trace set', () async {
      final (:out, testList: _, engine: engine) = await planSpec(lanedSpec);
      expect(exitCode, 0, reason: 'the laned plan must succeed: $out');
      final row = unitRowOf(engine, 'U1');
      expect(row, isNotNull, reason: 'the engine lane must carry U1:\n$engine');
      expect(
        row,
        contains('FR-001, TodoRepository.create'),
        reason:
            'the lane traces cell must match the test-list shape '
            '(acceptance criterion 3):\n$engine',
      );
    });

    test('U3: an FR with no traces continuation keeps the criterion-only '
        'cell (the fallback path, acceptance criterion 4)', () async {
      final (:out, testList: list, engine: _) = await planSpec(untracedSpec);
      expect(exitCode, 0, reason: 'plan must succeed: $out');
      final row = unitRowOf(list, 'U1');
      expect(row, isNotNull, reason: 'the plan must derive U1:\n$list');
      expect(
        row,
        contains('| FR-001 |'),
        reason: 'the criterion-only fallback cell is preserved:\n$list',
      );
      expect(
        row,
        isNot(contains('TodoRepository')),
        reason:
            'no contract names may be invented without a traces '
            'continuation:\n$list',
      );
    });

    test('U4: re-planning a list carrying full trace-set cells keeps the '
        'row id (the reconciliation read accepts the new shape)', () async {
      final tmp = Directory.systemTemp.createTempSync('issue_1310_replan_');
      try {
        final featureDir = p.join(tmp.path, 'specs', '1310-repro');
        await Directory(featureDir).create(recursive: true);
        final specFile = File(p.join(featureDir, 'spec.md'));
        final twoTracedFrs = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title
            traces: TodoRepository.create
- **FR-002**: System MUST let the user complete a todo
            traces: TodoRepository.create

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';
        // The spec AFTER the edit: FR-001 removed, so FR-002's behavior
        // re-derives as the parser's U1 — reconciliation must keep the
        // prior U2 row id keyed by the criterion token.
        final oneTracedFr = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-002**: System MUST let the user complete a todo
            traces: TodoRepository.create

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';
        await specFile.writeAsString(twoTracedFrs);
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          '1310-repro',
          '--project',
          tmp.path,
        ]);
        final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
        final firstList = await listFile.readAsString();
        expect(
          unitRowOf(firstList, 'U2'),
          isNotNull,
          reason: 'the first plan derives U1 and U2:\n$firstList',
        );

        // Spec edit: FR-001 gone. Re-plan.
        await specFile.writeAsString(oneTracedFr);
        await runner.runCapturing([
          'tdd',
          'plan',
          '1310-repro',
          '--project',
          tmp.path,
        ]);
        final reList = await listFile.readAsString();
        final row = unitRowOf(reList, 'U2');
        expect(
          row,
          isNotNull,
          reason:
              'the surviving FR-002 behavior must keep its prior U2 id — '
              'the reconciliation read must resolve the criterion token '
              'from the full-trace-set cell (FR-002, TodoRepository.create) '
              '— not renumber it to U1:\n$reList',
        );
        expect(row, contains('FR-002'), reason: reList);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('U7: re-planning a legacy criterion-only prior list still '
        'reconciles ids (compat path unchanged)', () async {
      final tmp = Directory.systemTemp.createTempSync('issue_1310_legacy_');
      try {
        final featureDir = p.join(tmp.path, 'specs', '1310-repro');
        await Directory(featureDir).create(recursive: true);
        final specFile = File(p.join(featureDir, 'spec.md'));
        const twoFrs = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title
- **FR-002**: System MUST let the user complete a todo

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';
        const oneFr = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1310-repro

### Layer Contracts

**Domain**:
- `TodoRepository`: `create(String title) -> bool`

## Functional Requirements

- **FR-002**: System MUST let the user complete a todo

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';
        await specFile.writeAsString(twoFrs);
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'plan',
          '1310-repro',
          '--project',
          tmp.path,
        ]);
        final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
        final firstList = await listFile.readAsString();
        expect(unitRowOf(firstList, 'U2'), isNotNull, reason: firstList);

        await specFile.writeAsString(oneFr);
        await runner.runCapturing([
          'tdd',
          'plan',
          '1310-repro',
          '--project',
          tmp.path,
        ]);
        final reList = await listFile.readAsString();
        expect(
          unitRowOf(reList, 'U2'),
          isNotNull,
          reason:
              'the legacy criterion-only reconciliation path is unchanged:\n'
              '$reList',
        );
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('issue #1310 — the declared-signature path is reachable via plan', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: '1310-repro');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    Future<void> planRepro() async {
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString(reproSpec);
      await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'plan', '1310-repro', '--project', fx.root.path]);
    }

    test('U5: gen derives the declared signature and a typed outcome '
        'assertion for a planned traced behavior', () async {
      await planRepro();
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
      expect(exitCode, 0, reason: 'gen must succeed: $out');
      final subject = await genSubjectOf(fx, 'U1');
      expect(
        subject,
        contains('create(String title) -> bool'),
        reason: 'the declared contract travels in the provenance header',
      );
      expect(
        subject,
        contains('bool subject_u1('),
        reason:
            'the declared return type is the subject signature — the '
            'legacy invented shape is gone:\n$subject',
      );
      final test = await genTestOf(fx, 'U1');
      expect(
        test,
        contains('expect(result, isA<bool>())'),
        reason: 'the declared scalar outcome is asserted mechanically',
      );
      expect(
        test,
        isNot(contains('vacuous-guard')),
        reason: 'a typed outcome assertion is present — not guard-only',
      );
    });

    test('U6: make certifies green for the planned behavior — the '
        'vacuous-green dead-end is gone', () async {
      await planRepro();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      // The run sequence: gen -> verify-red (the honest red evidence) ->
      // make. The declared scalar outcome keeps the pair assertable.
      final red = await runner.runCapturing([
        'tdd',
        'verify-red',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'the gen pair must certify red: $red');
      // The implementation step: the subject returns a dummy bool — the
      // generated test still asserts the DECLARED outcome, so make must
      // certify (a guard-only test in this state is exactly the
      // vacuous-green refusal the issue dead-ends on).
      final record = await fx.registryRecordOf('U1');
      final subjectFile = File(
        fixturePath(fx, record['subject_path'] as String),
      );
      final subject = await subjectFile.readAsString();
      await subjectFile.writeAsString(
        // The contract-derived stub body is an expression form:
        // `=> throw UnimplementedError('...: <declared signature>');`
        subject.replaceFirst(
          RegExp(r'=> throw UnimplementedError\([^;]*\);'),
          '=> false;',
        ),
      );
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'make must certify: $out');
      expect(
        out,
        isNot(contains('outcome=vacuous-green')),
        reason:
            'the real outcome assertion keeps the run off the '
            'vacuous-green dead-end',
      );
    });
  });
}
