@Tags(['slow'])
// SC-014 acceptance tests (spec 049-tdd-run, US2 / T013): interrupted runs
// resume from the persisted state — DONE skipped with re-entry at the
// state-implied step (A4), a kill mid-step re-executes the in-flight step
// (A5), and a corrupted state file stops the driver non-zero with the
// corruption and recovery path named (A6).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-resume';

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
      traces: 'FR-005',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-002',
      description: 'second behavior',
      traces: 'FR-005',
      state: 'PENDING',
      kind: 'unit',
    ),
    (
      id: 'B-003',
      description: 'third behavior',
      traces: 'FR-005',
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
    'A4: resume with B-002 RED skips DONE B-001 and re-enters at make',
    () async {
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRedEvidence('B-002');
      await fx.seedRunState(
        states: {'B-001': 'done', 'B-002': 'red', 'B-003': 'pending'},
      );

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );
      // B-001 (DONE) is not re-processed; B-002 re-enters at make, not gen;
      // B-003 runs its full cycle. 6 invocations < 12 for a fresh run.
      expect(fx.stepInvocations(), [
        'make B-002',
        'refactor B-002',
        'gen B-003',
        'verify-red B-003',
        'make B-003',
        'refactor B-003',
      ]);
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(
        (state['behavior_states'] as Map<String, dynamic>)['B-002'],
        'done',
      );
    },
  );

  test('A5: a kill mid-step resumes at the in-flight step', () async {
    await fx.seedRedEvidence('B-001');
    await fx.seedGreenEvidence('B-001');
    await fx.seedRedEvidence('B-002');
    // Simulate a crashed run: the process that held the make step for B-002
    // is dead, and the state file still carries the in-flight marker.
    final dead = await Process.start('sh', ['-c', 'exit 0']);
    final deadPid = dead.pid;
    await dead.exitCode;
    await fx.seedRunState(
      states: {'B-001': 'done', 'B-002': 'red', 'B-003': 'pending'},
      inFlightBehaviorId: 'B-002',
      inFlightStep: 'make',
      inFlightOwnerPid: deadPid,
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
      ),
      reason: out,
    );
    // The in-flight step re-executes: make B-002 runs again (its
    // idempotency is the step's own contract), then the run continues.
    expect(fx.stepInvocations().first, 'make B-002');
    expect(fx.stepInvocations(), hasLength(6));
  });

  test(
    'A6: corrupted run-state.json stops non-zero with recovery path',
    () async {
      const corrupt = '{"feature": "090-run-resume", "behavior_states": {';
      await File(fx.runStatePath).writeAsString(corrupt);

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=corrupt-state '
          'pending=0 red=0 green=0 done=0',
        ),
        reason: out,
      );
      // The corruption and the recovery path are both named.
      expect(out.toLowerCase(), contains('corrupt'));
      expect(out, contains('run-state.json'));
      expect(out.toLowerCase(), contains('delete'));
      // No guessing state: the corrupt file is left exactly as it was, and no
      // step was invoked.
      expect(await File(fx.runStatePath).readAsString(), corrupt);
      expect(fx.stepInvocations(), isEmpty);
    },
  );
}
