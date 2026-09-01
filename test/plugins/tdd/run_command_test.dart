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
}
