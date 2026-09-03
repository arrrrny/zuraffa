// Bug #846 (tdd-plan-coverage-gate) — the coverage gate.
//
// `zfa tdd plan` parsed what it could and SILENTLY SKIPPED the rest: a
// malformed requirement statement (`**FR-002:**` without the leading dash,
// a MUST sentence anchored to an FR id inside a table row) produced no
// behavior row and plan still exited 0 — the 100% TDD claim had no
// completeness proof (GitHub issue #846, [TDD-120]).
//
// The gate contract:
//
//   exit 0  — every FR-xxx / AC-n requirement statement maps to a
//             behavior row (or to an explicit `(manual: <owner>)`
//             declaration); the plan artifact carries the traceability
//             matrix plus the spec-contract hash
//   exit 2  — any requirement statement that produces no behavior row
//             and is not declared manual: offending spec line + fix
//             instruction, and NO plan artifacts are written
//   exit 3  — (verify) spec edited after plan: traceability hash drift,
//             re-plan required
//   corpus  — refuses a `complete` verdict while open gaps exist
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/corpus_fixture.dart';

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

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args(['plan', featureName]));
  }

  Future<String> runVerify() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'verify',
      '--feature',
      featureName,
      '--project',
      tmpDir.path,
    ]);
  }

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug846_gate_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    await Directory(featureDir).create(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<void> writeSpec(String spec) async {
    // Bug #919: the strict Template Version gate requires the marker on
    // every planned spec; these fixtures test the coverage and drift
    // gates, not the version gate, so all of them pin zuraffa-1.0.
    await File(p.join(featureDir, 'spec.md')).writeAsString(
      '**Template Version**: `zuraffa-1.0`\n\n$spec',
    );
  }

  group('plan coverage gate (exit 2 on silent gaps)', () {
    test(
      'RED: malformed FR bullet exits 2 naming the offending line',
      () async {
        await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args
**FR-002:** The system MUST log every invocation
''');

        final out = await runPlan();

        expect(
          exitCode,
          2,
          reason: 'uncovered FR-002 must fail the gate:\n$out',
        );
        expect(out, contains('FR-002'), reason: out);
        expect(out, contains('**FR-002:**'), reason: 'offending line: $out');
        expect(
          out.toLowerCase(),
          contains('fix'),
          reason: 'fix instruction required: $out',
        );
        // The gate refuses to emit artifacts from an incomplete plan.
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isFalse,
          reason: 'a failed plan must not write a test list',
        );
      },
    );

    test('RED: table-format MUST requirement exits 2', () async {
      await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args

| FR-002 | The system MUST log every invocation |
''');

      final out = await runPlan();

      expect(
        exitCode,
        2,
        reason: 'table-format edge was silently dropped:\n$out',
      );
      expect(out, contains('FR-002'), reason: out);
      expect(out, contains('| FR-002 |'), reason: 'offending line: $out');
    });

    test(
      'RED: AC statement with no behavior row and no manual declaration',
      () async {
        await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

| AC-2 | Given a slow path, When measured, Then feels fast |
''');

        final out = await runPlan();

        expect(exitCode, 2, reason: 'undeclared non-automatable AC:\n$out');
        expect(out, contains('AC-2'), reason: out);
      },
    );

    test('RED: manual declaration without an owner exits 2', () async {
      await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42
2. **Given** a slow path **When** measured **Then** feels fast (manual:)
''');

      final out = await runPlan();

      expect(
        exitCode,
        2,
        reason: 'manual declaration requires an owner:\n$out',
      );
      expect(out, contains('(manual:)'), reason: out);
    });
  });

  group('traceability artifact (the completeness proof)', () {
    test('RED: successful plan writes matrix + spec hash', () async {
      await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args
''');

      final out = await runPlan();

      expect(exitCode, 0, reason: out);
      final matrix = File(p.join(featureDir, 'tdd', 'traceability.md'));
      expect(matrix.existsSync(), isTrue, reason: out);
      final content = matrix.readAsStringSync();
      expect(content, contains('spec-hash: sha256:'));
      expect(content, contains('| FR-001'));
      expect(content, contains('| AC-1'));
      expect(content, contains('U1'));
      expect(content, contains('A1'));
    });

    test(
      'RED: (manual: owner) AC gets no behavior row, matrix marks manual',
      () async {
        await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42
2. **Given** a slow path **When** measured **Then** feels fast (manual: @arrrrny)
''');

        final out = await runPlan();

        expect(exitCode, 0, reason: out);
        final list = File(
          p.join(featureDir, 'tdd', 'test-list.md'),
        ).readAsStringSync();
        expect(list, contains('| A1 |'));
        expect(
          list,
          isNot(contains('| A2 |')),
          reason: 'a manual AC is not part of the automated loop',
        );
        final content = File(
          p.join(featureDir, 'tdd', 'traceability.md'),
        ).readAsStringSync();
        expect(content, contains('manual'));
        expect(content, contains('@arrrrny'));
        expect(content, contains('| AC-2'));
      },
    );
  });

  group('verify drift gate (exit 3)', () {
    test(
      'RED: spec edited after plan exits 3 with re-plan instruction',
      () async {
        const spec = '''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args
''';
        await writeSpec(spec);
        final planOut = await runPlan();
        expect(exitCode, 0, reason: planOut);

        // Spec edited AFTER the plan: the contract hash no longer matches.
        await writeSpec(
          '$spec\n- **FR-002**: The system MUST log invocations\n',
        );

        final out = await runVerify();

        expect(exitCode, 3, reason: 'drift must exit 3:\n$out');
        expect(out.toLowerCase(), contains('drift'), reason: out);
        expect(
          out.toLowerCase(),
          contains('re-plan'),
          reason: 'fix instruction: $out',
        );
      },
    );

    test('plan artifacts pass the verify hash re-check unchanged', () async {
      await writeSpec('''
# Spec: 001-demo

## Acceptance Scenarios

1. **Given** a fresh calculator **When** the user asks **Then** returns 42

## Functional Requirements

- **FR-001**: The system MUST return 42 when invoked with no args
''');
      final planOut = await runPlan();
      expect(exitCode, 0, reason: planOut);

      await runVerify();

      // No drift: verify proceeds past the hash check (it then reports
      // the mutation audit state, which for this bare fixture is not a
      // drift exit).
      expect(exitCode, isNot(3), reason: 'no spec edit, no drift');
    });
  });

  group('corpus refuses complete with open gaps', () {
    late CorpusFixture fx;

    Future<String> status() async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'corpus',
        'status',
        '--project',
        fx.root.path,
      ]);
    }

    test('RED: open gap on a done feature forces result=incomplete', () async {
      fx = await CorpusFixture.create();
      addTearDown(fx.dispose);
      Future<void> write(String rel, String content) async {
        final file = File(p.join(fx.root.path, rel));
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      }

      await fx.writeManifest([(name: 'f1-done', ready: true, reason: '')]);
      await write(
        '.zfa/corpus/progress.json',
        '{"features":{"f1-done":{"state":"done","gate":"pass"}},"dropped":[]}',
      );
      await write(
        '.zfa/corpus/gap-ledger.json',
        '['
            '{"id":"gap-001","kind":"gap","at":"2026-09-01T00:00:00Z",'
            '"feature":"f1-done","step":"verify","outcome":"fail_survived",'
            '"expected_result":"pass","failing_command":"zfa tdd verify",'
            '"status":"open"}]',
      );

      final out = await status();

      expect(
        exitCode,
        1,
        reason: 'a corpus with open gaps is NEVER complete:\n$out',
      );
      expect(out, contains('result=incomplete'), reason: out);
      expect(out, contains('open gaps'), reason: 'refusal reason: $out');
    });
  });
}
