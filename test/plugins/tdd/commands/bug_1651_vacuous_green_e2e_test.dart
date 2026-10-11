@Tags(['regression', 'e2e'])
// Issue #1651 — the engine lane certifies vacuous greens (E2E).
//
// `zfa tdd gen` for a unit behavior derives scaffold representative
// arguments `(0, 0)` and a type-only `isA<int>()` assertion, so the
// func-scaffolded `return 0;` dummy PASSES and the run certifies
// `result=complete` on subjects that implement nothing (#1259's class,
// reopened).
//
// Remediation pinned here (from the assessment):
//   1. gen derives the unit test's arguments + outcome assertion from
//      the spec's acceptance scenarios (`Given 2 and 3 ... Then the sum
//      5` → `subject_u1(2, 3)` + `expect(result, equals(5))`).
//   2. The dummy fails the generated test — the assertion discriminates.
//   3. `make` refuses terminal green when the paired unit subject body
//      is a scalar placeholder AND the test's assertion set is
//      type-only (outcome=vacuous-green, no green evidence).
//   4. Real implementations keep certifying green.
//
// Test map:
//   U1 — (AC1) plan+gen for the zcalc probe: the generated unit test
//        calls the subject with the scenario values and asserts the
//        concrete outcome.
//   U2 — (AC2) the generated test FAILS against a `return 0;` dummy
//        (real `dart test` subprocess — the assertion discriminates).
//   U3 — (AC3) make refuses the terminal green: dummy subject + type-
//        only test → outcome=vacuous-green, exit 1, no green evidence.
//   U4 — (AC4) a real implementation with a discriminating test
//        certifies green (outcome=skipped, evidence appended).
//   U5 — (AC3) the run driver's vacuous-green stop names the placeholder
//        remedy (stopped_at=<id>:make preserved — machine contract).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const zcalcSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: zcalc1651

### Layer Contracts

**Function**:
- `Calculator`: `add(int a, int b) -> int`, `divide(int a, int b) -> double`

### Functional Requirements

- **FR-001**: The engine MUST add two integers via `Calculator.add` and
  return their sum.
  traces: Calculator.add

- **FR-002**: The engine MUST divide two integers via `Calculator.divide`
  and return their quotient.
  traces: Calculator.divide

## Acceptance Scenarios

1. **Given** the integers 2 and 3, **When** `Calculator.add` is called,
   **Then** the sum 5 is returned.

2. **Given** the integers 6 and 3, **When** `Calculator.divide` is called,
   **Then** the quotient 2.0 is returned.
''';

/// The type-only unit test shape (the post-#1259 generated form) that
/// the func dummy satisfies — the vacuity under fix.
String typeOnlyTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id \u2014 $description', () {
    final result = (() {
      try {
        return subject.$symbol(0, 0);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isA<int>());
  });
}
''';
}

/// The func-scaffolded dummy (the exact #1651 trigger).
String scalarDummySubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol(int a, int b) {
  return 0;
}
''';
}

/// A real implementation of the behavior — discriminating greens keep
/// certifying.
String realAddSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol(int a, int b) {
  return a + b;
}
''';
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: 'zcalc1651');
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
    ], workingDirectory: fx.root.path);
    expect(
      pubGet.exitCode,
      0,
      reason: 'pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1651 — scenario-derived unit assertions (E2E)', () {
    test('U1 (AC1): the generated unit test asserts the scenario\'s '
        'concrete values, not types', () async {
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString(zcalcSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        'zcalc1651',
        '--project',
        fx.root.path,
      ]);
      final gen = await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      expect(gen, contains('verdict='), reason: gen);
      expect(exitCode, 0, reason: gen);

      final record = await fx.registryRecordOf('U1');
      final testContent = await File(
        p.join(fx.root.path, record['test_path'] as String),
      ).readAsString();

      expect(
        testContent,
        contains('(2, 3)'),
        reason:
            'the capture calls the subject with the spec scenario\'s '
            'concrete arguments — never the (0, 0) representatives:\n'
            '$testContent',
      );
      expect(
        testContent,
        contains('equals(5)'),
        reason: 'the assertion pins the concrete outcome (the sum 5)',
      );
      expect(
        testContent,
        isNot(contains('isA<int>()')),
        reason: 'the type-only assertion is the vacuity under fix',
      );
    });

    test('U2 (AC2): the generated test FAILS against the func dummy — '
        'the assertion discriminates', () async {
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString(zcalcSpec);
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'plan',
        'zcalc1651',
        '--project',
        fx.root.path,
      ]);
      await runner.runCapturing([
        'tdd',
        'gen',
        'U1',
        '--project',
        fx.root.path,
      ]);
      final record = await fx.registryRecordOf('U1');
      // The func-scaffolded state: the stub rewritten to `return 0;`.
      await File(
        p.join(fx.root.path, record['subject_path'] as String),
      ).writeAsString(scalarDummySubject('U1'));

      final run = await Process.run('dart', [
        'test',
        record['test_path'] as String,
      ], workingDirectory: fx.root.path);
      final transcript = '${run.stdout}${run.stderr}';
      expect(
        run.exitCode,
        isNot(0),
        reason:
            'a `return 0;` dummy MUST fail the scenario assertion:\n'
            '$transcript',
      );
      expect(
        transcript,
        contains('Expected:'),
        reason:
            'the failure is the value assertion (equals(5) vs 0), never a '
            'compile error:\n$transcript',
      );
      expect(transcript, isNot(contains('Compilation failed')));
    });
  });

  group('issue #1651 — make refuses placeholder greens (E2E)', () {
    test('U3 (AC3): a dummy subject whose test only type-checks cannot '
        'certify green — outcome=vacuous-green, no evidence', () async {
      const id = 'B-1651';
      const description = 'the engine adds two integers';
      await fx.seedTestList([
        (
          id: id,
          description: description,
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: id,
        description: description,
        sourceCriterion: 'FR-001',
        testContent: typeOnlyTest(id, description),
      );
      // make requires a certified red before it drives the cycle; the
      // hashless legacy evidence fails open to the live drift re-run.
      await fx.seedRedEvidence(id);
      // registerBehavior records the subject path but does not write the
      // subject — write the func-scaffolded dummy there.
      final subjectPath = p.join(
        fx.root.path,
        'lib',
        '${id.toLowerCase().replaceAll('-', '_')}_subject.dart',
      );
      await File(subjectPath).parent.create(recursive: true);
      await File(subjectPath).writeAsString(scalarDummySubject(id));

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', id, '--project', fx.root.path]);

      expect(exitCode, 1, reason: 'a placeholder green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'), reason: out);
      expect(
        out,
        contains('placeholder'),
        reason: 'the refusal names the placeholder body: $out',
      );
      final log = await File(fx.cycleLogPath).readAsString();
      expect(
        log,
        isNot(contains('## Cycle: $id (green)')),
        reason: 'no green evidence may be appended for a placeholder green',
      );
    });

    test('U4 (AC4): a real implementation with a discriminating test '
        'certifies green unchanged', () async {
      const id = 'B-1651';
      const description = 'the engine adds two integers';
      await fx.seedTestList([
        (
          id: id,
          description: description,
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: id,
        description: description,
        sourceCriterion: 'FR-001',
        testContent:
            '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id \u2014 $description', () {
    final result = (() {
      try {
        return subject.subject_${id.toLowerCase().replaceAll('-', '_')}(2, 3);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals(5));
  });
}
''',
      );
      await fx.seedRedEvidence(id);
      final subjectPath = p.join(
        fx.root.path,
        'lib',
        '${id.toLowerCase().replaceAll('-', '_')}_subject.dart',
      );
      await File(subjectPath).parent.create(recursive: true);
      await File(subjectPath).writeAsString(realAddSubject(id));

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', id, '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'), reason: out);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle: $id (green)'), reason: out);
    });
  });
}
