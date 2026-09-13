@Tags(['slow'])
// Issue #1592 — the born-green transition never converges: a
// born-green-certified BLOCKED contract behavior re-enters the cycle at
// verify-red (spec 1007's blocked window, `_stepsFor` index 1), whose
// already-green test unexpected-greens; make refuses not-certified-red and
// the #1411 hand-stop re-prescribes the exact `--born-green` command that
// already ran. Every re-run repeats the identical stop — the loop never
// converges.
//
// Root cause: the #1324 green-evidence guard in `_stepsFor` fires only when
// the computed window starts at gen (`start == 0`); the blocked re-entry
// computes `start == 1`, so a backed green evidence entry never lifts the
// window past verify-red.
//
// Contract under test (issue #1592, spec
// 1592-born-green-transition-never-converges):
//   B1 — a born-green-certified blocked behavior resumes at make (the
//        drift-skip / adoption transition, #694/#1331): no verify-red
//        re-entry, no gen over the certified pair, no born-green
//        re-prescription; the run completes.
//   B2 — convergence without manual re-entry: the drive after the
//        certification completes the behavior (done=1); a further re-run
//        is a no-op skip (the prescription loop is gone).
//   B3 — normal (non-born-green) blocked resume keeps the verify-red
//        re-entry: without green evidence the guard never fires (the
//        hard constraint — no behavior change for the #1544 class).
//   B4 — unbacked green evidence keeps the pre-#1592 window (#1324 SC-4):
//        a blocked behavior whose certified test file is gone still
//        re-enters verify-red and names stale-artifacts on the
//        contradiction drive.
//
// Fast tier within the slow tag: the driver runs over the scripted fake
// zfa binary (no real `dart test` children) — the issue_1308 driver-test
// convention, shared with bug_1324_resume_stale_artifacts_wedge_test.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  Future<String> drive(String feature) =>
      runCli(['run', feature, '--zfa-bin', fx.fakeZfaBin]);

  /// Seed the born-green-certified blocked shape: the contract behavior
  /// parked BLOCKED (run-state), its registry record present (the gen
  /// artifacts of the first drive), the certified GREEN test on disk (the
  /// seams hand-implemented) and the born-green evidence entry in the
  /// cycle log (`zfa tdd make <id> --born-green`, #1411 — green WITHOUT a
  /// prior certified red, backed on disk).
  Future<void> seedBornGreenBlocked(String id) async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the $id behavior',
        traces: 'FR-001',
        state: 'BLOCKED',
        kind: 'contract',
      ),
    ]);
    await fx.seedRunState(states: {id: 'blocked'});
    await fx.registerBehavior(
      id: id,
      description: 'the $id behavior',
      testContent: TddFixture.greenTest('the $id behavior'),
    );
    await fx.seedGreenEvidence(id);
  }

  tearDown(() {
    exitCode = 0;
  });

  test(
    'B1: born-green-certified blocked behavior resumes at make — no verify-red re-entry (SC-1)',
    () async {
      const feature = '1592-born-green-converges';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      await seedBornGreenBlocked('A1');
      // The scripted contradiction the pre-fix drive produced: verify-red
      // unexpected-green (the already-green subject) then make refusing
      // not-certified-red (#1411 arm) — the loop's stop shape.
      await fx.setStepOutcome('verify-red', 'A1', 'unexpected-green');
      await fx.setStepOutcome('make', 'A1', 'not-certified-red');
      // The make re-certification the fix drives into: the #694 drift-skip
      // transition (green evidence appended, exit 0, outcome=skipped).
      await fx.setStepOutcome('make', 'A1', 'skip');

      final out = await drive(feature);
      final invocations = fx.stepInvocations();

      expect(out, contains('result=complete'), reason: out);
      expect(
        invocations,
        isNot(contains('verify-red A1')),
        reason:
            'the born-green-certified blocked behavior must not re-enter '
            'verify-red — the guard covers the blocked window: $invocations',
      );
      expect(
        invocations,
        isNot(contains('gen A1')),
        reason:
            'the certified pair is backed on disk — gen would clobber it '
            '(the #1324 invariant, unchanged): $invocations',
      );
      expect(
        invocations,
        contains('make A1'),
        reason:
            'the cycle resumes at make — the drift-skip / adoption '
            'transition re-certifies honestly: $invocations',
      );
      expect(
        invocations,
        contains('refactor A1'),
        reason: 'the resumed cycle completes its ladder: $invocations',
      );
      expect(
        out,
        isNot(contains('--born-green')),
        reason:
            'the transition converged — the #1411 prescription must not '
            'fire for a backed born-green blocked behavior: $out',
      );
    },
  );

  test(
    'B2: convergence without manual re-entry — the re-run is a no-op skip (SC-3)',
    () async {
      const feature = '1592-no-reentry';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      await seedBornGreenBlocked('A1');
      await fx.setStepOutcome('make', 'A1', 'skip');

      final out = await drive(feature);
      expect(out, contains('result=complete'), reason: out);
      expect(
        out,
        contains('run: feature=$feature result=complete pending=0 red=0 '
            'green=0 done=1'),
        reason: 'the behavior landed on done — not parked, not stopped: '
            '$out',
      );

      // The loop-killer: a SECOND run drives nothing and completes. Pre-fix
      // this re-run stopped at the same make → not-certified-red and
      // re-prescribed the born-green command.
      fx.clearStepInvocations();
      final out2 = await drive(feature);
      final invocations2 = fx.stepInvocations();

      expect(out2, contains('result=complete'), reason: out2);
      expect(
        invocations2,
        isEmpty,
        reason:
            'the converged feature must not re-drive any step on the '
            'next run — the prescription loop is gone: $invocations2',
      );
      expect(
        out2,
        isNot(contains('--born-green')),
        reason: out2,
      );
    },
  );

  test(
    'B3: normal (non-born-green) blocked resume keeps the verify-red re-entry',
    () async {
      const feature = '1592-normal-blocked';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      // Blocked WITHOUT green evidence: the #1544 class — the contract
      // test is red (the declared contract is unimplemented) and the run
      // re-enters at verify-red honestly (spec 1007).
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the A1 behavior',
          traces: 'FR-001',
          state: 'BLOCKED',
          kind: 'contract',
        ),
      ]);
      await fx.seedRunState(states: {'A1': 'blocked'});
      await fx.registerBehavior(id: 'A1', description: 'the A1 behavior');
      await fx.setStepOutcome('verify-red', 'A1', 'ok');
      await fx.setStepOutcome('make', 'A1', 'ok');

      final out = await drive(feature);
      final invocations = fx.stepInvocations();

      expect(out, contains('result=complete'), reason: out);
      expect(
        invocations,
        contains('verify-red A1'),
        reason:
            'without green evidence the blocked window is unchanged — '
            'verify-red re-entry stands (the hard constraint): '
            '$invocations',
      );
      expect(invocations, contains('make A1'), reason: out);
    },
  );

  test(
    'B4: unbacked green evidence keeps the pre-#1592 window (#1324 SC-4)',
    () async {
      const feature = '1592-unbacked-evidence';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      // Green evidence whose certified test file is GONE (the #1264
      // orphaned class): greenTestBacked is false, the guard must not
      // fire, and the pre-#1592 blocked window re-enters verify-red —
      // the #1324 stale-artifacts contract stands unchanged.
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the A1 behavior',
          traces: 'FR-001',
          state: 'BLOCKED',
          kind: 'contract',
        ),
      ]);
      await fx.seedRunState(states: {'A1': 'blocked'});
      await fx.registerBehavior(
        id: 'A1',
        description: 'the A1 behavior',
        writeTestFile: false,
      );
      await fx.seedGreenEvidence('A1');
      await fx.setStepOutcome('verify-red', 'A1', 'unexpected-green');
      await fx.setStepOutcome('make', 'A1', 'subject-drift');

      final out = await drive(feature);
      final invocations = fx.stepInvocations();

      expect(
        invocations,
        contains('verify-red A1'),
        reason:
            'unbacked green evidence does not lift the blocked window — '
            'the #1324 SC-4 compat rule holds: $invocations',
      );
      expect(out, contains('result=stale-artifacts'), reason: out);
      expect(out, contains('stopped_at=A1:make'), reason: out);
      expect(
        out,
        contains('--> fix: zfa tdd reset $feature'),
        reason: 'the #1324 prescription is unchanged: $out',
      );
    },
  );
}
