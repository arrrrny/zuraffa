@Tags(['slow'])
// Driver-level tests for RunCommand (spec 049-tdd-run, U19-U29 / T008,
// T012, T015, T016, T019). The command runs in-process through
// CliRunner.runCapturing; the four step commands are the fixture's
// scripted fake zfa binary spawned as real sub-processes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-driver';

  Future<String> drive({String? zfaBin}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin ?? fx.fakeZfaBin,
    ]);
  }

  Future<void> seedThree() => fx.seedTestList([
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

  Future<Map<String, dynamic>> readState() async =>
      jsonDecode(await File(fx.runStatePath).readAsString())
          as Map<String, dynamic>;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await seedThree();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'U19: per-behavior step order is gen -> verify-red -> make -> refactor',
    () async {
      final out = await drive();

      expect(exitCode, 0, reason: out);
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
    },
  );

  test('U20: state is persisted after every completed step', () async {
    await fx.setStepOutcome('make', 'B-002', 'unexpressible');

    final out = await drive();

    expect(exitCode, isNot(0), reason: out);
    // B-001's four advances were all persisted; B-002's verify-red advance
    // (pending -> red) was persisted before the failing make ran; B-003
    // was never touched.
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'red',
      'B-003': 'pending',
    });
    // The state file carries no in-flight marker after an honest stop.
    expect(state.containsKey('in_flight_behavior_id'), isFalse);
    expect(state.containsKey('in_flight_step'), isFalse);
  });

  test(
    'U21: a done claim without red+green evidence demotes to the evidence-backed state',
    () async {
      // Red only: demoted to red -> re-driven from make.
      await fx.seedRedEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'done'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations().first, 'make B-001');

      // No evidence at all: demoted to pending -> full re-drive.
      fx.clearStepInvocations();
      exitCode = 0;
      await File(fx.runStatePath).delete();
      await File(fx.cycleLogPath).delete();
      await fx.seedRunState(states: {'B-001': 'done'});

      final out2 = await drive();

      expect(exitCode, 0, reason: out2);
      expect(fx.stepInvocations().first, 'gen B-001');
    },
  );

  test(
    'U22: resume skips DONE and re-enters at the state-implied step',
    () async {
      // RED -> make; GREEN -> refactor; DONE -> skip.
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRedEvidence('B-002');
      await fx.seedGreenEvidence('B-002');
      await fx.seedRedEvidence('B-003');
      await fx.seedGreenEvidence('B-003');
      await fx.seedRunState(
        states: {'B-001': 'done', 'B-002': 'red', 'B-003': 'green'},
      );

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // Strictly less work than a fresh run (3 invocations vs 12).
      expect(fx.stepInvocations(), [
        'make B-002',
        'refactor B-002',
        'refactor B-003',
      ]);
    },
  );

  test('U23: an in-flight step at load re-executes that step', () async {
    await fx.seedRedEvidence('B-001');
    await fx.seedGreenEvidence('B-001');
    final dead = await Process.start('sh', ['-c', 'exit 0']);
    final deadPid = dead.pid;
    await dead.exitCode;
    await fx.seedRunState(
      states: {'B-001': 'done', 'B-002': 'pending'},
      inFlightBehaviorId: 'B-002',
      inFlightStep: 'gen',
      inFlightOwnerPid: deadPid,
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // The crashed gen for B-002 re-executed, then the sequence continued.
    expect(fx.stepInvocations().first, 'gen B-002');
    expect(fx.stepInvocations(), [
      'gen B-002',
      'verify-red B-002',
      'make B-002',
      'refactor B-002',
      'gen B-003',
      'verify-red B-003',
      'make B-003',
      'refactor B-003',
    ]);
  });

  test(
    'U24: the failure matrix stops the run with correct residual state',
    () async {
      const matrix = [
        ('gen', 'pending'),
        ('verify-red', 'pending'),
        ('make', 'red'),
        ('refactor', 'green'),
      ];
      for (final (step, residual) in matrix) {
        final fixture = await TddFixture.create(featureName: feature);
        addTearDown(fixture.dispose);
        await fixture.writeFakeZfa();
        await fixture.seedTestList([
          (
            id: 'B-001',
            description: 'first behavior',
            traces: 'FR-007',
            state: 'PENDING',
            kind: 'unit',
          ),
          (
            id: 'B-002',
            description: 'later behavior',
            traces: 'FR-007',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await fixture.setStepOutcome(step, 'B-001', 'boom');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fixture.root.path,
          '--zfa-bin',
          fixture.fakeZfaBin,
        ]);

        expect(exitCode, isNot(0), reason: '$step: $out');
        expect(out, contains('result=stopped'), reason: '$step: $out');
        expect(out, contains('stopped_at=B-001:$step'), reason: '$step: $out');
        // B-002 was never started.
        expect(
          fixture.stepInvocations().where((l) => l.contains('B-002')),
          isEmpty,
          reason: step,
        );
        // Residual state is the last fully-completed state for B-001.
        final state =
            jsonDecode(await File(fixture.runStatePath).readAsString())
                as Map<String, dynamic>;
        expect(
          (state['behavior_states'] as Map<String, dynamic>)['B-001'],
          residual,
          reason: step,
        );
        exitCode = 0;
      }
    },
  );

  test('U24: a stubbed/missing step binary is a runner-error stop', () async {
    final out = await drive(zfaBin: '/nonexistent/zfa-fake');

    expect(exitCode, isNot(0), reason: out);
    expect(out, contains('result=runner-error'), reason: out);
    expect(out, contains('stopped_at=B-001:gen'), reason: out);
    expect(out, contains('behavior=B-001'), reason: out);
    // B-001 stays pending; no in-flight marker persists after the stop.
    final state = await readState();
    expect(
      (state['behavior_states'] as Map<String, dynamic>)['B-001'],
      'pending',
    );
    expect(state.containsKey('in_flight_behavior_id'), isFalse);
  });

  test(
    'U24: a certified step that wrote no evidence is a misfire stop',
    () async {
      await fx.setStepOutcome('verify-red', 'B-001', 'ok-no-evidence');

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('result=runner-error'), reason: out);
      expect(out, contains('stopped_at=B-001:verify-red'), reason: out);
      expect(out.toLowerCase(), contains('evidence'));
      expect(fx.stepInvocations().where((l) => l.contains('B-002')), isEmpty);
    },
  );

  test('U25: each step completion prints its progress line', () async {
    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(out, contains('[run] B-001 gen -> ok'));
    expect(out, contains('[run] B-001 verify-red -> certified'));
    expect(out, contains('[run] B-001 make -> green'));
    expect(out, contains('[run] B-001 refactor -> clean'));
    expect(out, contains('[run] B-003 refactor -> clean'));
  });

  test(
    'U26: the summary line carries feature, result, counts, stopped_at',
    () async {
      var out = await drive();
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );

      exitCode = 0;
      // Fresh state for the stopped case: the previous run completed.
      await File(fx.runStatePath).delete();
      await File(fx.cycleLogPath).delete();
      await fx.setStepOutcome('make', 'B-003', 'unexpressible');
      out = await drive();
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=0 red=1 green=0 done=2 '
          'stopped_at=B-003:make',
        ),
        reason: out,
      );
    },
  );

  test('U27: exit 0 exactly on complete-with-evidence', () async {
    await drive();
    expect(exitCode, 0);

    exitCode = 0;
    await File(fx.runStatePath).delete();
    await File(fx.cycleLogPath).delete();
    await fx.setStepOutcome('refactor', 'B-002', 'regression');
    await drive();
    expect(exitCode, isNot(0));
  });

  test(
    'U28: an all-DONE run performs zero step invocations and exits 0',
    () async {
      await drive();
      exitCode = 0;
      fx.clearStepInvocations();

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), isEmpty);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=3',
        ),
        reason: out,
      );
    },
  );

  test(
    'U29: new test-list rows enter as PENDING, DONE behaviors untouched',
    () async {
      await drive();
      exitCode = 0;
      fx.clearStepInvocations();

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
          description: 'new behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), [
        'gen B-004',
        'verify-red B-004',
        'make B-004',
        'refactor B-004',
      ]);
      final state = await readState();
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
        'B-002': 'done',
        'B-003': 'done',
        'B-004': 'done',
      });
    },
  );
}
