@Tags(['slow'])
// Driver-level tests for RunCommand (spec 049-tdd-run, U19-U29 / T008,
// T012, T015, T016, T019). The command runs in-process through
// CliRunner.runCapturing; the four step commands are the fixture's
// scripted fake zfa binary spawned as real sub-processes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
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
    // Bug #657: a UNIT behavior's unexpressible make now defers like the
    // acceptance deferral (bug #625) instead of stopping the feature —
    // so B-003 runs its full phase-1 cycle (its refactor defers while
    // B-002 sits RED), and the honest stop lands at the phase-2 make
    // re-attempt of B-002 (stopped_at=B-002:make).
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'red',
      'B-003': 'green',
    });
    // The state file carries no in-flight marker after an honest stop.
    expect(state.containsKey('in_flight_behavior_id'), isFalse);
    expect(state.containsKey('in_flight_step'), isFalse);
  });

  test(
    'U21: a done claim without red+green evidence demotes to the evidence-backed state',
    () async {
      // Red only: demoted to red -> re-driven from make. The gen artifacts
      // are registered so the red claim's state-implied make re-entry
      // applies (bug #720 demotes artifact-less claims to gen instead).
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
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
      // RED -> make; GREEN -> refactor; DONE -> skip. The gen artifacts
      // are registered so the state-implied re-entries apply (bug #720
      // demotes artifact-less claims to gen instead).
      await fx.registerBehavior(id: 'B-002', description: 'second behavior');
      await fx.registerBehavior(id: 'B-003', description: 'third behavior');
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

    // Discriminating case (verification remediation F1): the in-flight
    // marker sits on a step LATER than the state-implied one — a crash
    // during verify-red, after gen had completed and advanced. Re-entry
    // must happen at the in-flight verify-red, NOT at a redundant gen.
    exitCode = 0;
    fx.clearStepInvocations();
    await fx.seedRunState(
      states: {'B-001': 'done', 'B-002': 'pending'},
      inFlightBehaviorId: 'B-002',
      inFlightStep: 'verify-red',
      inFlightOwnerPid: deadPid,
    );

    final out2 = await drive();

    expect(exitCode, 0, reason: out2);
    expect(fx.stepInvocations().first, 'verify-red B-002');
    expect(fx.stepInvocations().where((l) => l == 'gen B-002'), isEmpty);
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

  test('bug #691: verify-red reporting unexpected-green on an already-green '
      'behavior skips to make instead of stopping the run', () async {
    // The behavior was completed by prior work: its full manual cycle
    // left red+green evidence in the cycle log, and the target test
    // already passes — so the scripted verify-red classifies it
    // `unexpected-green` (certified=false). The pre-#691 driver treated
    // that as a step failure and hard-stopped the whole feature.
    await fx.setStepOutcome('verify-red', 'B-001', 'unexpected-green');
    await fx.setStepOutcome('make', 'B-001', 'skip');
    await fx.seedRedEvidence('B-001');
    await fx.seedGreenEvidence('B-001');

    final out = await drive();

    // The run no longer stops at B-001:verify-red.
    expect(exitCode, 0, reason: out);
    expect(
      out,
      isNot(contains('step failed — behavior=B-001 step=verify-red')),
      reason: out,
    );
    expect(out, contains('[run] B-001 verify-red -> unexpected-green'));
    expect(
      out,
      contains(
        '[run] B-001 verify-red -> skipped (already '
        'green)',
      ),
    );
    // Skipped TO MAKE: the window continued with make (not a full
    // re-drive of gen, not a stop) and completed the behavior.
    expect(
      fx.stepInvocations().where((l) => l.contains('B-001')),
      containsAllInOrder(['verify-red B-001', 'make B-001']),
    );
    // Later behaviors were never blocked.
    expect(fx.stepInvocations(), contains('gen B-002'));
    // Whole feature completes.
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=0 done=3',
      ),
      reason: out,
    );
  });

  test('FR-008: the driver never modifies test/ or lib/ itself', () async {
    // Give the fixture a test/ and lib/ tree the fake steps never touch.
    await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
    await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
    await File(
      p.join(fx.root.path, 'lib', 'subject.dart'),
    ).writeAsString('int subject() => 42;\n');
    await File(
      p.join(fx.root.path, 'test', 'subject_test.dart'),
    ).writeAsString('void main() {}\n');
    final snapshot = fx.checksumTestAndLib();

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // Nothing under test/ or lib/ changed across the whole run: the only
    // tree the driver writes is specs/<feature>/tdd/run-state.json.
    expect(fx.checksumTestAndLib(), snapshot);
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

  test('bug 625: acceptance make unexpressible defers to phase 2 — unit '
      'completes first, acceptance flips green, feature DONE exit 0', () async {
    // Outside-in order as `zfa tdd plan` writes it: A1 (acceptance) in the
    // outer loop, U1 (unit) in the inner loop. A1's make reports
    // unexpressible on its phase-1 attempt (the planner's by-design
    // refusal of acceptance prose — the bug #625 deadlock signature),
    // so the driver defers it instead of stopping the feature; phase 2
    // re-attempts make against the project where U1 exists and flips A1
    // green.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    // Attempt 1 (phase 1): unexpressible. Attempt 2 (phase 2): green —
    // the units exist now.
    await fx.setStepOutcome('make', 'A1', 'unexpressible\nok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // Phase 1 runs the uniform cycle: A1's make is attempted and defers
    // on unexpressible; U1 makes green and its refactor defers too (bug
    // #635 — A1 sits RED, the suite is knowingly red). Phase 2 re-attempts
    // A1's make, then refactors every behavior on the fully-green suite.
    expect(fx.stepInvocations(), [
      'gen A1',
      'verify-red A1',
      'make A1',
      'gen U1',
      'verify-red U1',
      'make U1',
      'make A1',
      'refactor A1',
      'refactor U1',
    ]);
    // The honest outcome line plus the deferral disposition marker
    // (FR-009 progress lines; bug #625/#635 phase markers).
    expect(out, contains('[run] A1 make -> unexpressible'));
    expect(out, contains('[run] A1 make -> deferred (phase 2)'));
    expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
    expect(out, contains('[run] A1 make -> green (phase 2)'));
    expect(out, contains('[run] A1 refactor -> clean (phase 2)'));
    expect(out, contains('[run] U1 refactor -> clean (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
  });

  test('bug 826: a make reporting outcome=no-op (empty plan — no active '
      'plugins) defers to phase 2 exactly like unexpressible — the loop '
      'is not stopped by a nothing-to-generate behavior', () async {
    // A1's make resolves to an EMPTY inner `zfa make` plan ("No active
    // plugins to run.") — the bug #826 empty-plan shape. The real make
    // records `outcome=no-op` without spawning the analyzer-heavy
    // subprocess; the driver must defer the behavior to phase 2 rather
    // than stopping the feature, so a corpus run is unblocked by
    // nothing-to-generate behaviors.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'crud repository for order line 1.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
    ]);
    // Attempt 1 (phase 1): no-op. Attempt 2 (phase 2): green — plugins
    // landed between phases in this scripted scenario.
    await fx.setStepOutcome('make', 'A1', 'no-op\nok');
    await fx.setStepOutcome('refactor', 'A1', 'ok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(fx.stepInvocations(), [
      'gen A1',
      'verify-red A1',
      'make A1',
      'make A1',
      'refactor A1',
    ]);
    expect(out, contains('[run] A1 make -> no-op'));
    expect(out, contains('[run] A1 make -> deferred (phase 2)'));
    expect(out, contains('[run] A1 make -> green (phase 2)'));
    expect(out, contains('[run] A1 refactor -> clean (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=1',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {'A1': 'done'});
  });

  test('bug 635: unit refactor defers while the acceptance sits red — '
      'phase 2 makes every acceptance green, then refactors on the '
      'fully-green suite', () async {
    // The bug #635 deadlock: the two-phase driving (bug #625) deferred
    // the acceptance make but not the unit refactor. `refactor` demands
    // an absolutely green suite (spec 048 FR-001) — impossible while
    // A1's test sits honestly RED — so the pre-fix driver stopped every
    // acceptance-bearing feature at U1:refactor with outcome=not-green.
    // The deferral concept was half-applied: make deferred, refactor not.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.setStepOutcome('make', 'A1', 'unexpressible\nok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // Phase 1 drives units through gen -> verify-red -> make only: U1's
    // refactor is DEFERRED while A1 sits RED — never attempted against a
    // knowingly-red suite. Phase 2a flips A1 green; phase 2b runs
    // refactor for every behavior, per behavior, on the fully-green
    // suite — refactor's absolute-green contract (spec 048 FR-001) is
    // met by construction.
    expect(fx.stepInvocations(), [
      'gen A1',
      'verify-red A1',
      'make A1',
      'gen U1',
      'verify-red U1',
      'make U1',
      'make A1',
      'refactor A1',
      'refactor U1',
    ]);
    expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
    expect(out, contains('[run] A1 refactor -> clean (phase 2)'));
    expect(out, contains('[run] U1 refactor -> clean (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
  });

  test(
    'bug 625/635: acceptance unexpressible at phase 2 is an honest stop '
    'at A1:make with the unit behavior GREEN (its refactor deferred)',
    () async {
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the entity exists and is buildable.',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U1',
          description: 'unit behavior backing A1',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // The planner cannot express acceptance prose by design — every
      // make attempt reports unexpressible. Phase 2 is a real, honest
      // stop, with the unit GREEN — its refactor rides the next phase-2
      // pass once the acceptance flips green (bug #635) — instead of the
      // old whole-feature deadlock.
      await fx.setStepOutcome('make', 'A1', 'unexpressible');

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      // The doomed refactor was never attempted: U1 made green and
      // deferred its refactor while A1 sat RED (bug #635); the run
      // stopped at A1's phase-2 make — bounded, resumable progress.
      expect(fx.stepInvocations(), [
        'gen A1',
        'verify-red A1',
        'make A1',
        'gen U1',
        'verify-red U1',
        'make U1',
        'make A1',
      ]);
      expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
      expect(out, contains('[run] A1 make -> deferred (phase 2)'));
      expect(out, contains('result=stopped pending=0 red=1 green=1 done=0'));
      expect(out, contains('stopped_at=A1:make'), reason: out);
      final state = await readState();
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'A1': 'red',
        'U1': 'green',
      });
    },
  );

  test('bug 625: deferral is scoped to the unexpressible signature — any '
      'other acceptance make failure still stops the run (FR-007)', () async {
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    // A genuine tooling failure is NOT the by-design unexpressible
    // refusal: it must stop the run immediately, no deferral.
    await fx.setStepOutcome('make', 'A1', 'boom');

    final out = await drive();

    expect(exitCode, isNot(0), reason: out);
    expect(fx.stepInvocations(), ['gen A1', 'verify-red A1', 'make A1']);
    expect(out, isNot(contains('deferred (phase 2)')), reason: out);
    expect(out, contains('result=stopped pending=1 red=1 green=0 done=0'));
    expect(out, contains('stopped_at=A1:make'), reason: out);
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'red',
      'U1': 'pending',
    });
  });

  test('bug 694: a make reporting skipped (already green) advances the '
      'behavior and the run proceeds past it — no drift stop', () async {
    // B-002's make is the issue #694 re-run scenario: the target test
    // already passes from a prior run, so make reports the skip
    // transition (outcome=skipped, exit 0, green evidence appended —
    // the fake's `skip` token mirrors the real contract). The loop
    // must advance B-002 GREEN and continue with B-003 instead of
    // stopping at outcome=drift.
    await fx.setStepOutcome('make', 'B-002', 'skip');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(out, contains('[run] B-002 make -> skipped'), reason: out);
    expect(out, isNot(contains('outcome=drift')), reason: out);
    // The run proceeded: B-002's refactor ran, then B-003's full cycle.
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
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'done',
      'B-003': 'done',
    });
  });

  test(
    'bug 734: refactor defers while a pending behavior carries generated '
    'stubs — the run drives it first, then refactors every behavior',
    () async {
      // The #734 deadlock: phase 1 stopped early at U2 (the #731
      // false-positive family), leaving U3+ PENDING with generated stubs
      // whose tests throw UnimplementedError. On resume the already-green
      // behaviors re-enter at refactor, refactor's full-suite preflight
      // (spec 048 FR-001) refuses against the red stubs, and every
      // refactor reports not-green — blocking the feature for behaviors
      // that ARE green. The bug #635 deferral only engaged on RED rows;
      // a pending-with-gen-artifacts row is not RED, so the driver spawned
      // refactor into a knowingly-red suite anyway.
      //
      // Seeded resume state: A1 + U1 + U2 GREEN with complete evidence and
      // their refactors outstanding; U3 PENDING with gen artifacts (its
      // stub test is red on disk — exactly the state the real full-suite
      // preflight refuses).
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the entity exists and is buildable.',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U1',
          description: 'unit behavior backing A1',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U2',
          description: 'second unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U3',
          description: 'pending stub behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // The green claims carry gen artifacts (bug #720 keeps their
      // state-implied refactor re-entry) — registry records only, the
      // stub files on disk are U3's.
      await fx.registerBehavior(
        id: 'A1',
        description: 'the entity exists and is buildable.',
        writeTestFile: false,
      );
      await fx.registerBehavior(
        id: 'U1',
        description: 'unit behavior backing A1',
        writeTestFile: false,
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'second unit behavior',
        writeTestFile: false,
      );
      await fx.registerBehavior(id: 'U3', description: 'pending stub behavior');
      for (final id in ['A1', 'U1', 'U2']) {
        await fx.seedRedEvidence(id);
        await fx.seedGreenEvidence(id);
      }
      await fx.seedRunState(
        states: {'A1': 'green', 'U1': 'green', 'U2': 'green', 'U3': 'pending'},
      );

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // The green behaviors' refactors DEFER (no spawn) while U3 sits
      // pending with generated stubs; the run drives U3's full cycle
      // first, and only then do the deferred refactors run (phase 2b) —
      // bounded progress instead of the A1:refactor not-green deadlock.
      expect(fx.stepInvocations(), [
        'gen U3',
        'verify-red U3',
        'make U3',
        'refactor U3',
        'refactor A1',
        'refactor U1',
        'refactor U2',
      ]);
      expect(out, contains('[run] A1 refactor -> deferred (phase 2)'));
      expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
      expect(out, contains('[run] U2 refactor -> deferred (phase 2)'));
      expect(out, contains('[run] A1 refactor -> clean (phase 2)'));
      expect(out, contains('[run] U1 refactor -> clean (phase 2)'));
      expect(out, contains('[run] U2 refactor -> clean (phase 2)'));
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 done=4',
        ),
        reason: out,
      );
      final state = await readState();
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'A1': 'done',
        'U1': 'done',
        'U2': 'done',
        'U3': 'done',
      });
    },
  );

  test('bug 734 + bug 828: an evidence-less green claim is re-driven from '
      'make (the earliest incomplete step) instead of riding into refactor; '
      'the phase-2b per-behavior gate stays as the defensive net', () async {
    // Bug #734 built a pre-spawn skip gate: a green claim whose own test
    // is not certified green (a brownfield/seeded state or a lost
    // cycle-log) used to ride into refactor and die at the post-spawn
    // evidence misfire (runner-error), stopping the pass for every other
    // behavior — so the gate skipped it BEFORE the spawn with a recorded
    // reason and the honest stop named it.
    //
    // Bug #828 supersedes that band-aid with real resume reconciliation:
    // a green claim WITHOUT green evidence no longer survives the merge —
    // it demotes to the highest state the evidence backs (red, when a red
    // entry exists) and the resume re-drives make, which re-certifies the
    // behavior's own test green honestly. The re-certified behavior then
    // refactors in the phase-2b pass like any other green behavior. The
    // per-behavior gate remains in the driver as a defensive net (the
    // #682 bootstrap promotion can still present a green state whose red
    // half is missing, which misfires at the evidence gate honestly).
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U2',
        description: 'pending stub behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    // U2 sits pending WITH gen artifacts so the greens' phase-1
    // refactors defer (bug #734) and actually reach the phase-2b pass.
    // The green claims carry gen artifacts too (bug #720 keeps their
    // state-implied re-entries) — registry records only.
    await fx.registerBehavior(
      id: 'A1',
      description: 'the entity exists and is buildable.',
      writeTestFile: false,
    );
    await fx.registerBehavior(
      id: 'U1',
      description: 'unit behavior backing A1',
      writeTestFile: false,
    );
    await fx.registerBehavior(id: 'U2', description: 'pending stub behavior');
    // A1: a green claim WITHOUT green evidence — bug #828 reconciles it
    // to red (its red evidence stands) and the resume re-drives make.
    // U1: a green claim WITH complete evidence keeps its resume semantics.
    await fx.seedRedEvidence('A1');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(
      states: {'A1': 'green', 'U1': 'green', 'U2': 'pending'},
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // A1 re-enters at make (re-certification), its phase-1 refactor
    // defers while U2 sits pending with artifacts (bug #734), and the
    // re-certified refactor completes in the phase-2b pass.
    expect(fx.stepInvocations(), [
      'make A1',
      'gen U2',
      'verify-red U2',
      'make U2',
      'refactor U2',
      'refactor A1',
      'refactor U1',
    ]);
    expect(out, contains('[run] A1 make -> green'));
    expect(out, contains('[run] A1 refactor -> deferred (phase 2)'));
    expect(out, contains('[run] U1 refactor -> deferred (phase 2)'));
    expect(out, isNot(contains('[run] A1 refactor -> skipped')));
    expect(out, contains('[run] A1 refactor -> clean (phase 2)'));
    expect(out, contains('[run] U1 refactor -> clean (phase 2)'));
    // The whole feature completes: every behavior re-certified honestly.
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 '
        'done=3',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
      'U2': 'done',
    });
  });

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

  // -------------------------------------------------------------------
  // Spec 050 (FR-007 / U8) — the repo's hand-written 6-column
  // extension dialect (specs/046–049's shape) must be drivable: the
  // run gets PAST list-reading (no `result=runner-error`, no
  // `expected 4 columns`) and drives the rows through the fake steps.
  // -------------------------------------------------------------------

  test('U8/050: run drives a hand-written 6-column extension-dialect list '
      'past list-reading to all-DONE', () async {
    // Seed the list directly in the extension's hand-written shape —
    // the fixture's seedTestList only writes plan's 4-column shape.
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| B-001 | first legacy behavior | FR-001 | example | PENDING | sc_legacy_test.dart::B-001 |
| B-002 | second legacy behavior | FR-002 | example | PENDING | sc_legacy_test.dart::B-002 |
''');

    final out = await drive();

    // The dialect no longer bricks the loop's front door.
    expect(out, isNot(contains('expected 4 columns')), reason: out);
    expect(out, isNot(contains('result=runner-error')), reason: out);

    // The rows resolved and were driven through every step.
    expect(fx.stepInvocations(), [
      'gen B-001',
      'verify-red B-001',
      'make B-001',
      'refactor B-001',
      'gen B-002',
      'verify-red B-002',
      'make B-002',
      'refactor B-002',
    ]);
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=0 done=2',
      ),
      reason: out,
    );
    expect(exitCode, 0, reason: out);
  });

  // ------------------------------------------------------------------
  // Bug #657: a UNIT behavior's unexpressible make is a deferral, not a
  // feature-blocking stop.
  // ------------------------------------------------------------------

  test('bug 657: a unit behavior whose make reports unexpressible defers '
      'to phase 2 — later behaviors still run, the honest stop lands at '
      'the phase-2 re-attempt', () async {
    await fx.setStepOutcome('make', 'B-002', 'unexpressible');

    final out = await drive();

    // The deferral is announced in phase 1...
    expect(
      out,
      contains('[run] B-002 make -> deferred (phase 2)'),
      reason: out,
    );
    // ...B-003 still runs its full cycle (refactor defers while B-002
    // sits RED)...
    expect(
      fx.stepInvocations(),
      containsAllInOrder([
        'make B-002',
        'gen B-003',
        'verify-red B-003',
        'make B-003',
      ]),
    );
    expect(
      fx.stepInvocations().where((l) => l == 'refactor B-003'),
      isEmpty,
      reason: 'refactor must defer while B-002 sits RED',
    );
    // ...and the honest stop happens at the phase-2 re-attempt, after
    // everything else ran.
    expect(
      out,
      contains(
        'run: feature=$feature result=stopped pending=0 red=1 green=1 '
        'done=1 stopped_at=B-002:make',
      ),
      reason: out,
    );
    expect(exitCode, isNot(0), reason: out);
  });

  test('bug 657: a unit make that reports unexpressible then ok completes '
      'the whole feature (the deferral is re-attempted, not fatal)', () async {
    // Multi-line config: phase-1 attempt unexpressible, phase-2 re-attempt ok.
    await fx.setStepOutcome('make', 'B-002', 'unexpressible\nok');

    final out = await drive();

    expect(
      out,
      contains('[run] B-002 make -> deferred (phase 2)'),
      reason: out,
    );
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=0 done=3',
      ),
      reason: out,
    );
    expect(exitCode, 0, reason: out);
    // B-002's make ran twice: the phase-1 attempt and the phase-2
    // re-attempt.
    expect(fx.stepInvocations().where((l) => l == 'make B-002'), hasLength(2));
  });

  test('bug 682: a fresh run bootstraps run-state from existing cycle-log '
      'evidence instead of re-driving certified behaviors', () async {
    // Brownfield feature: no run-state.json yet, but the cycle log already
    // certifies B-001 (red+green) and carries red-only evidence for B-002;
    // B-003 has no evidence at all. FR-003 (evidence beats state) must
    // promote the reconciled states instead of treating the feature as
    // never-started. B-002's gen artifacts are registered so its red
    // claim keeps the state-implied make re-entry (bug #720 demotes
    // artifact-less claims to gen instead).
    await fx.registerBehavior(id: 'B-002', description: 'second behavior');
    await fx.seedRedEvidence('B-001');
    await fx.seedGreenEvidence('B-001');
    await fx.seedRedEvidence('B-002');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // B-001 (red+green -> done) is skipped entirely; B-002 (red)
    // re-enters at make; B-003 (no evidence) drives the full cycle.
    expect(fx.stepInvocations(), [
      'make B-002',
      'refactor B-002',
      'gen B-003',
      'verify-red B-003',
      'make B-003',
      'refactor B-003',
    ]);
    expect(out, contains('1 already done — skipping'));
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'done',
      'B-003': 'done',
    });
  });

  test('bug 682: an all-pending run-state.json with complete evidence '
      'promotes every behavior to done and drives nothing', () async {
    // The issue's exact repro state: run-state.json exists, every behavior
    // claimed pending, while the cycle log certifies red AND green for all
    // of them. Nothing may be re-driven; the state file must be reconciled
    // to done.
    for (final id in const ['B-001', 'B-002', 'B-003']) {
      await fx.seedRedEvidence(id);
      await fx.seedGreenEvidence(id);
    }
    await fx.seedRunState(
      states: {'B-001': 'pending', 'B-002': 'pending', 'B-003': 'pending'},
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(fx.stepInvocations(), isEmpty);
    expect(out, contains('3 already done — skipping'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=0 done=3',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'done',
      'B-003': 'done',
    });
  });

  test('bug 682: green-only evidence promotes to green and the owed '
      'refactor honestly misfires while red evidence is missing', () async {
    // The issue's mapping, green-only -> green (make certified, refactor
    // outstanding), composed with the pre-existing honesty contract: the
    // bootstrap must not fabricate the missing red half, so the resumed
    // refactor certifies and then fails the evidence check (FR-003/
    // FR-011) — the behavior stays GREEN and the run stops naming it.
    // The gen artifacts are registered so the green/red claims keep
    // their state-implied re-entries (bug #720 demotes artifact-less
    // claims to gen instead).
    await fx.registerBehavior(id: 'B-001', description: 'first behavior');
    await fx.registerBehavior(id: 'B-002', description: 'second behavior');
    await fx.seedGreenEvidence('B-001');
    await fx.seedRedEvidence('B-002');

    final out = await drive();

    expect(fx.stepInvocations(), [
      'make B-002',
      'refactor B-002',
      'gen B-003',
      'verify-red B-003',
      'make B-003',
      'refactor B-003',
      'refactor B-001',
    ]);
    expect(
      out,
      contains(
        'refactor certified but evidence for "B-001" is incomplete in '
        'tdd/cycle-log.md (red: false, green: true)',
      ),
      reason: out,
    );
    expect(
      out,
      contains(
        'result=runner-error pending=0 red=0 green=1 done=2 '
        'stopped_at=B-001:refactor',
      ),
      reason: out,
    );
    expect(exitCode, 2);
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'green',
      'B-002': 'done',
      'B-003': 'done',
    });
  });

  test('bug 720: a clean state with residual red evidence starts at gen, '
      'not make', () async {
    // The issue's exact repro: run-state.json, artifacts.json and the gen
    // files are all gone, but the cycle log still carries red evidence for
    // B-001 from a prior interrupted run that never wrote an in-flight
    // marker. The #682 bootstrap promotes B-001 to RED, and the red claim's
    // make re-entry is only valid when the gen artifacts exist — the real
    // make refuses "no gen artifacts" otherwise. The driver must check the
    // artifacts, not the state claim, and start B-001 at gen.
    await fx.seedRedEvidence('B-001');
    // No run-state.json, no artifacts.json record, no test files: a fully
    // clean state except the residual red evidence.

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // B-001 re-drives the FULL cycle from gen (the red claim is not trusted
    // without artifacts); B-002/B-003 are untouched pendings on the same
    // full cycle.
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
    expect(out, contains('[run] B-001 gen -> ok'));
    expect(out, contains('[run] B-001 verify-red -> certified'));
    expect(out, contains('[run] B-001 make -> green'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=0 done=3',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'B-001': 'done',
      'B-002': 'done',
      'B-003': 'done',
    });
  });

  test('bug 720: an in-flight marker still re-enters at its step even '
      'when the gen artifacts are missing', () async {
    // The gen check only fills in a MISSING resume decision — it must not
    // override a live in-flight marker (U23): a crash mid-make left the
    // marker, and the resume re-enters at make exactly as before.
    final dead = await Process.start('sh', ['-c', 'exit 0']);
    final deadPid = dead.pid;
    await dead.exitCode;
    await fx.seedRedEvidence('B-001');
    await fx.seedRunState(
      states: {'B-001': 'red', 'B-002': 'pending', 'B-003': 'pending'},
      inFlightBehaviorId: 'B-001',
      inFlightStep: 'make',
      inFlightOwnerPid: deadPid,
    );

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(fx.stepInvocations().first, 'make B-001');
    expect(fx.stepInvocations().where((l) => l == 'gen B-001'), isEmpty);
  });

  test('bug 720: a red claim WITH gen artifacts still re-enters at make '
      '(the artifacts check does not regress certified resumes)', () async {
    // The artifacts check only demotes artifact-less claims. B-001 is red
    // WITH its registry record (gen completed in a prior run; verify-red
    // certified; the run stopped before make), so the state-implied make
    // re-entry stays exactly as the pre-#720 contract.
    await fx.registerBehavior(id: 'B-001', description: 'first behavior');
    await fx.seedRedEvidence('B-001');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(fx.stepInvocations().first, 'make B-001');
    expect(fx.stepInvocations().where((l) => l == 'gen B-001'), isEmpty);
  });

  test('bug 734 v2: refactor defers while a pending behavior has a red stub on '
      'disk WITHOUT a registry record — the preflight refusal must not spawn '
      'into the knowingly-red suite', () async {
    // The REOPENED #734 state: the original fix's deferral trusts the
    // registry ("artifact-less pending rows contribute no red risk"),
    // but the issue's own state is "U3-U44 pending (not generated)"
    // while their stubs throw UnimplementedError — stubs ON DISK
    // WITHOUT records (an interrupted gen, a wiped artifacts.json, or
    // gen outside the driver). For such a row the pre-spawn deferral
    // does not engage, the already-green behavior's refactor spawns
    // into the knowingly-red suite, the full-suite preflight (spec 048
    // FR-001) refuses, and the run dies at <id>:refactor — the #734
    // deadlock, back.
    //
    // Seeded resume state: A1 GREEN with complete evidence and its
    // refactor outstanding; U1 PENDING with a red stub at the gen
    // default layout (test/tdd/u1_test.dart) but NO registry record.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(
      id: 'A1',
      description: 'the entity exists and is buildable.',
      writeTestFile: false,
    );
    // U1: the stub file exists on disk (red UnimplementedError stub, the
    // gen default layout) but the registry has NO record for it.
    final stubDir = Directory(p.join(fx.root.path, 'test', 'tdd'));
    await stubDir.create(recursive: true);
    await File(
      p.join(stubDir.path, 'u1_test.dart'),
    ).writeAsString(TddFixture.redTest('unit behavior backing A1'));
    await fx.seedRedEvidence('A1');
    await fx.seedGreenEvidence('A1');
    await fx.seedRunState(states: {'A1': 'green', 'U1': 'pending'});

    final out = await drive();

    expect(exitCode, 0, reason: out);
    // The pre-spawn deferral must engage on the disk stub: A1's refactor
    // defers BEFORE any spawn, U1 is driven to green first, and only
    // then do the refactors run (U1 inline, A1 in the phase-2b pass).
    // Pre-fix the first invocation is `refactor A1` — a spawn into the
    // knowingly-red suite.
    expect(fx.stepInvocations(), [
      'gen U1',
      'verify-red U1',
      'make U1',
      'refactor U1',
      'refactor A1',
    ]);
    expect(out, contains('[run] A1 refactor -> deferred (phase 2)'));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
  });

  test('bug 734 v2: a phase-1 refactor whose preflight refuses (not-green) '
      'defers instead of stopping the run — the pending row is still driven '
      'and the deferred refactor completes in phase 2b', () async {
    // The safety net for redness the pre-spawn model cannot see (an
    // outside failure, a #741-baseline-tolerated failure, a stub at a
    // non-default path): the spawned refactor's preflight refuses, the
    // refusal is side-effect-free (refactor modifies zero files when it
    // refuses), so the driver DEFERS the behavior (stays GREEN) instead
    // of pass-fatally stopping — the pending row is still driven (which
    // may flip the suite green), and the deferred refactor re-spawns in
    // the phase-2b pass. Pre-fix the refusal took the honest-stop path:
    // the run died at A1:refactor with U1 never driven — the reopened
    // deadlock.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(
      id: 'A1',
      description: 'the entity exists and is buildable.',
      writeTestFile: false,
    );
    // U1 is pending with NO registry record and NO stub file — the
    // pre-spawn deferral (red rows / pending-with-artifacts) must NOT
    // engage, so A1's refactor actually spawns and the post-spawn
    // refusal path is exercised. The fake step binary certifies U1's
    // gen/verify-red/make and writes its red+green evidence.
    await fx.seedRedEvidence('A1');
    await fx.seedGreenEvidence('A1');
    await fx.seedRunState(states: {'A1': 'green', 'U1': 'pending'});
    // The spawned refactor's preflight refuses on the first spawn
    // (phase 1 — the suite is red from a source the driver's row model
    // cannot see); by the later re-spawns the suite is green (U1 was
    // driven) and the refactor completes.
    await fx.setStepOutcome('refactor', 'A1', 'not-green\nok');

    final out = await drive();

    expect(exitCode, 0, reason: out);
    expect(fx.stepInvocations(), [
      'refactor A1', // phase 1: spawned, preflight refused (not-green)
      'gen U1', // the pending row is still driven
      'verify-red U1',
      'make U1',
      'refactor U1', // U1's own refactor completes inline
      'refactor A1', // phase 2b: the deferred refactor completes
    ]);
    expect(out, contains('[run] A1 refactor -> not-green'));
    expect(out, contains('[run] A1 refactor -> deferred (phase 2)'));
    expect(out, isNot(contains('step failed — behavior=A1 step=refactor')));
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 done=2',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'done',
      'U1': 'done',
    });
  });

  test('bug 734 v2: a phase-2b refactor whose preflight refuses is skipped '
      'with a recorded reason while the rest of the pass completes', () async {
    // The phase-2b twin of the safety net: when the spawned refactor's
    // preflight refuses in the REFACTOR PASS itself (the suite is still
    // red from a source the row model cannot see — the refusal will not
    // clear within this run), the behavior is SKIPPED with a recorded
    // reason (stays GREEN, never a fake DONE) and the pass continues
    // for every other behavior; the run ends honestly naming the skips
    // and the resume path. Pre-fix the refusal stopped the pass for
    // everyone: U1's phase-2b refactor never spawned.
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'the entity exists and is buildable.',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'unit behavior backing A1',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U2',
        description: 'pending stub behavior',
        traces: 'FR-001',
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
      writeTestFile: false,
    );
    // U2 sits pending WITH a registry record so the greens' phase-1
    // refactors defer pre-spawn (the original #734 deferral) and
    // actually reach the phase-2b pass.
    await fx.registerBehavior(id: 'U2', description: 'pending stub behavior');
    await fx.seedRedEvidence('A1');
    await fx.seedGreenEvidence('A1');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(
      states: {'A1': 'green', 'U1': 'green', 'U2': 'pending'},
    );
    // A1's refactor refuses on EVERY spawn (the redness never clears
    // within this run); U1's refactors succeed.
    await fx.setStepOutcome('refactor', 'A1', 'not-green');

    final out = await drive();

    expect(exitCode, 1, reason: out);
    // The phase-1 deferrals (A1, U1) are pre-spawn and log no
    // invocations; U2 is driven and refactored inline; in phase 2b the
    // spawned refactor A1 refuses and — post-fix — the pass continues
    // to U1. Pre-fix the pass dies AT `refactor A1`.
    expect(fx.stepInvocations(), [
      'gen U2',
      'verify-red U2',
      'make U2',
      'refactor U2', // U2 completes inline (nothing pending anymore)
      'refactor A1', // phase 2b: spawned, preflight refused -> SKIPPED
      'refactor U1', // phase 2b: the pass continues past the refusal
    ]);
    expect(out, contains('[run] A1 refactor -> not-green'));
    expect(out, contains('[run] A1 refactor -> skipped (suite not green)'));
    expect(out, contains('[run] U1 refactor -> clean (phase 2)'));
    expect(out, isNot(contains('step failed — behavior=A1 step=refactor')));
    // The honest end-of-run stop names the refusal skip and the resume
    // path; A1 stays GREEN (resumable), never a fake DONE.
    expect(out, contains('refactor skipped for A1'));
    expect(out, contains('suite not green'));
    expect(
      out,
      contains(
        'run: feature=$feature result=stopped pending=0 red=0 green=1 '
        'done=2 stopped_at=A1:refactor',
      ),
      reason: out,
    );
    final state = await readState();
    expect(state['behavior_states'] as Map<String, dynamic>, {
      'A1': 'green',
      'U1': 'done',
      'U2': 'done',
    });
  });

  test(
    'bug 734 v2: a refactor regression (re-proof failure) still stops the '
    'run honestly — the refusal safety net does not capture real failures',
    () async {
      // The safety net is scoped to the preflight REFUSAL (outcome=not-
      // green, side-effect-free). A refactor whose re-proof suite fails
      // (outcome=regression) has already applied its passes — a REAL
      // failure the run must stop for, exactly as before.
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the entity exists and is buildable.',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.registerBehavior(
        id: 'A1',
        description: 'the entity exists and is buildable.',
        writeTestFile: false,
      );
      await fx.seedRedEvidence('A1');
      await fx.seedGreenEvidence('A1');
      await fx.seedRunState(states: {'A1': 'green'});
      await fx.setStepOutcome('refactor', 'A1', 'regression');

      final out = await drive();

      expect(exitCode, 1, reason: out);
      expect(out, contains('[run] A1 refactor -> regression'));
      expect(
        out,
        contains('step failed — behavior=A1 step=refactor outcome=regression'),
      );
      expect(
        out,
        isNot(contains('deferred (phase 2)')),
        reason: 'a regression is not a deferral',
      );
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=0 red=0 green=1 '
          'done=0 stopped_at=A1:refactor',
        ),
        reason: out,
      );
    },
  );
}
