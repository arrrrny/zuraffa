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
      await fx.registerBehavior(id: 'B-002', description: 'second behavior');
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

    // Discriminating case (verification remediation F1): the kill landed
    // during verify-red — after gen completed — so the in-flight step is
    // LATER than the state-implied one. The resume must re-enter at
    // verify-red, not at a redundant gen (strictly less work).
    exitCode = 0;
    fx.clearStepInvocations();
    await fx.seedRunState(
      states: {'B-001': 'done', 'B-002': 'pending', 'B-003': 'pending'},
      inFlightBehaviorId: 'B-002',
      inFlightStep: 'verify-red',
      inFlightOwnerPid: deadPid,
    );

    final out2 = await drive();

    expect(exitCode, 0, reason: out2);
    expect(fx.stepInvocations().first, 'verify-red B-002');
    expect(fx.stepInvocations().where((l) => l == 'gen B-002'), isEmpty);
    expect(fx.stepInvocations(), hasLength(7));
  });

  test('bug 625: resume across the phase boundary — acceptance sits RED while '
      'the unit completes first, then acceptance flips green', () async {
    // Interrupted mid-phase-1: A1 (acceptance) certified red with its
    // make deferred; U1 (unit) certified red, its make never ran. No
    // in-flight marker — the previous run stopped honestly. The gen
    // artifacts are registered so the red claims keep their
    // state-implied make re-entries (bug #720 demotes artifact-less
    // claims to gen instead).
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-005',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-005',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(
      id: 'A1',
      description: 'the entity exists and is buildable.',
      writeTestFile: false,
    );
    await fx.registerBehavior(
      id: 'U1',
      description: 'unit behavior backing A1',
    );
    await fx.seedRedEvidence('A1');
    await fx.seedRedEvidence('U1');
    await fx.seedRunState(states: {'A1': 'red', 'U1': 'red'});
    // The resumed phase-1 make attempt for A1 hits the by-design
    // unexpressible refusal again and defers; phase 2 flips it green.
    await fx.setStepOutcome('make', 'A1', 'unexpressible\nok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // The unit completes FIRST (U1 re-enters at its state-implied step);
    // only then does phase 2 flip the deferred acceptance behavior
    // green. A1 sits RED between the phases — resumable mid-corpus.
    // U1's refactor defers while A1 is RED (bug #635) and runs in the
    // phase-2 refactor pass on the fully-green suite.
    expect(fx.stepInvocations(), [
      'make A1',
      'make U1',
      'make A1',
      'refactor A1',
      'refactor U1',
    ]);
    expect(out, contains('[run] A1 make -> deferred (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state =
        jsonDecode(await File(fx.runStatePath).readAsString())
            as Map<String, dynamic>;
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
  });

  test('bug 625: kill during an acceptance make re-enters at the in-flight '
      'step and completes', () async {
    // Phase 1 completed U1 (DONE with evidence); A1 sits RED — deferred
    // at its phase-1 make, or killed mid-make. The in-flight marker
    // survived either way; the resume re-enters at the make.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-005',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-005',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedRedEvidence('A1');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    final dead = await Process.start('sh', ['-c', 'exit 0']);
    final deadPid = dead.pid;
    await dead.exitCode;
    await fx.seedRunState(
      states: {'A1': 'red', 'U1': 'done'},
      inFlightBehaviorId: 'A1',
      inFlightStep: 'make',
      inFlightOwnerPid: deadPid,
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // Strictly less work: U1 (DONE) untouched; A1 re-enters at the
    // in-flight make — its make is expressible now (units exist), so
    // the uniform pass completes it; phase 2 finds nothing left.
    expect(fx.stepInvocations(), ['make A1', 'refactor A1']);
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state =
        jsonDecode(await File(fx.runStatePath).readAsString())
            as Map<String, dynamic>;
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
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
