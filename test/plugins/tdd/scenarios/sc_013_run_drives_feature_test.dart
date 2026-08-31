@Tags(['slow'])
// SC-013 acceptance tests (spec 049-tdd-run, US1 / T009): `zfa tdd run`
// drives a fixture feature end to end — all-PENDING to all-DONE in list
// order (A1), idempotent re-run (A2), and mid-project list growth (A3) —
// through the real CLI entry point with scripted fake step binaries.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-fixture';

  Future<String> drive() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  Future<void> seedThreeBehaviors() => fx.seedTestList([
    (
      id: 'B-001',
      description: 'first behavior',
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-002',
      description: 'second behavior',
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-003',
      description: 'third behavior',
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await seedThreeBehaviors();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'A1: drives a 3-behavior feature to all-DONE, exit 0, evidence',
    () async {
      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );

      // FR-001: list order, four steps per behavior, in sequence.
      expect(fx.stepInvocations(), [
        'gen B-001',
        'verify-red B-001',
        'make B-001',
        'refactor B-001',
        'gen B-002',
        'verify-red B-002',
        'make B-002',
        'refactor B-002',
        'gen B-003',
        'verify-red B-003',
        'make B-003',
        'refactor B-003',
      ]);

      // FR-004: state persisted, all DONE.
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
        'B-002': 'done',
        'B-003': 'done',
      });

      // FR-003: one red and one green evidence entry per behavior.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(
        RegExp(r'^- kind: red$', multiLine: true).allMatches(log).length,
        3,
      );
      expect(
        RegExp(r'^- kind: green$', multiLine: true).allMatches(log).length,
        3,
      );
      for (final id in ['B-001', 'B-002', 'B-003']) {
        final redSections = RegExp(
          '## Cycle: $id \\(red\\)',
        ).allMatches(log).length;
        final greenSections = RegExp(
          '## Cycle: $id \\(green\\)',
        ).allMatches(log).length;
        expect(redSections, 1, reason: 'exactly one red entry for $id');
        expect(greenSections, 1, reason: 'exactly one green entry for $id');
      }
    },
  );

  test(
    'A2: re-run on a completed feature changes nothing and exits 0',
    () async {
      await drive();
      exitCode = 0;
      final stateBefore = await File(fx.runStatePath).readAsString();
      final logBefore = await File(fx.cycleLogPath).readAsString();
      fx.clearStepInvocations();

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );
      // Nothing to do: zero step invocations, zero evidence added, state file
      // untouched byte for byte.
      expect(fx.stepInvocations(), isEmpty);
      expect(await File(fx.cycleLogPath).readAsString(), logBefore);
      expect(await File(fx.runStatePath).readAsString(), stateBefore);
    },
  );

  test('bug 625: acceptance-only feature defers every make at phase 1, then '
      'phase 2 re-attempts make + refactor in list order', () async {
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'A2',
        description: 'the feature end-to-end scenario holds.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
    ]);
    // Both makes report unexpressible on their phase-1 attempt (the
    // bug #625 signature) and flip green when phase 2 re-attempts them.
    await fx.setStepOutcome('make', 'A1', 'unexpressible\nok');
    await fx.setStepOutcome('make', 'A2', 'unexpressible\nok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // Phase 1: each acceptance behavior runs its uniform cycle; both
    // makes defer on unexpressible. Phase 2: make + refactor in list
    // order.
    expect(fx.stepInvocations(), [
      'gen A1',
      'verify-red A1',
      'make A1',
      'gen A2',
      'verify-red A2',
      'make A2',
      'make A1',
      'refactor A1',
      'make A2',
      'refactor A2',
    ]);
    expect(out, contains('[run] A1 make -> deferred (phase 2)'));
    expect(out, contains('[run] A2 make -> deferred (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
  });

  test(
    'A3: a behavior appended mid-project is driven, DONE ones untouched',
    () async {
      await drive();
      exitCode = 0;
      fx.clearStepInvocations();

      await seedThreeBehaviors();
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-003',
          description: 'third behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-004',
          description: 'fourth behavior appended mid-project',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=4',
        ),
        reason: out,
      );
      // Only the new behavior is driven; the DONE three are not re-processed.
      expect(fx.stepInvocations(), [
        'gen B-004',
        'verify-red B-004',
        'make B-004',
        'refactor B-004',
      ]);
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
        'B-002': 'done',
        'B-003': 'done',
        'B-004': 'done',
      });
    },
  );
}
