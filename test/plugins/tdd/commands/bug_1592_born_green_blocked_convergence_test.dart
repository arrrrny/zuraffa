@Tags(['slow'])
// Issue #1592 — the born-green transition never converges for a BLOCKED
// contract behavior; every re-run stops at the same `make ->
// not-certified-red` and prescribes the `--born-green` command that
// ALREADY ran (the #1411 stop arm), forever.
//
// The structural trap: the #1324 green-evidence guard in the run
// driver's `_stepsFor` only fires when `start == 0`, but the #1007
// BLOCKED contract arm re-enters at index 1 (`verify-red`). A
// born-green-certified blocked behavior (the `make <id> --born-green`
// green certification is on the journal and backed on disk) therefore
// skips the guard and re-drives `verify-red -> make`: verify-red grades
// the already-passing contract test unexpected-green, and the flagless
// make the driver spawns refuses `not-certified-red` (the lane has no
// certified red — BLOCKED-never-RED, issue #1007; born-green is
// green-WITHOUT-red, issue #1411; the flagless make cannot reach the
// #694 skip transition — the certified-red gate refuses first). The
// #1411 stop arm prescribes `--born-green` again — the loop never
// converges.
//
// Fix under test (issue #1592): the green-evidence guard's SCOPE extends
// to the blocked state for the born-green-CERTIFIED class — the
// behavior whose LAST green entry carries the #1411 journal marker.
// Such a behavior re-enters at the phase-2 refactor window, where the
// #1542 evidence check already accepts the green-only born-green
// certification. The run converges to `result=complete` without manual
// re-entry, and the NEXT run re-enters at refactor only (the #1542
// steady state — make never re-spawns).
//
// Design note (reconciles the earlier B1/B2 WIP drafts on this branch):
// resuming the born-green blocked cycle at MAKE cannot converge — the
// flagless make the driver spawns has no certified red to pass the
// precondition gate (`make_command.dart` step 2), so it refuses
// `not-certified-red` on every attempt; only the refactor window
// re-certifies, and only for the born-green-certified class. Marker-less
// blocked shapes (a plain green-only contract, U-1542-1's pinned
// verify-red -> make -> refactor window) and blocked claims without
// backed green evidence keep the exact pre-#1592 windows.
//   U-1592-1 — the loop: blocked + born-green certification converges
//              through refactor ONLY (verify-red/make never spawn);
//              pre-fix this run stopped at `<id>:hand` prescribing the
//              already-run `--born-green`. The NEXT run re-enters at
//              refactor only and completes — the loop is dead.
//   U-1592-2 — regression: a NORMAL blocked resume (NO green evidence)
//              keeps the exact pre-#1592 window (verify-red re-drives,
//              the #1007 verdict parks, `result=blocked`).
//   U-1592-3 — regression: green evidence WITHOUT its certified test
//              file on disk (the unbacked class) keeps the exact
//              pre-#1324 windows (SC-4 conservatism, unchanged).
//   U-1592-4 — ported from the earlier B3 draft: a normal blocked
//              resume whose re-drive certifies red-first completes the
//              full ladder (verify-red -> make -> refactor).
//   U-1592-5 — ported from the earlier B4 draft: unbacked green
//              evidence against a drifting subject keeps the #1324
//              stale-artifacts stop and prescription, byte-for-byte.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/born_green.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1592-born-green-convergence';
  const id = 'contract:A7';

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

  Future<Map<String, dynamic>> readState() async =>
      jsonDecode(await File(fx.runStatePath).readAsString())
          as Map<String, dynamic>;

  /// Seed a green-evidence entry for [behaviorId] exactly like the
  /// issue #1411 `make --born-green` transition appends it: the
  /// `- evidence:` field starts with the born-green journal marker
  /// (the anchored #1566 probe) and the `- test:` line names [testPath].
  Future<void> seedBornGreenEvidence(
    String behaviorId, {
    required String testPath,
  }) async {
    final file = File(fx.cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- evidence: $bornGreenEvidenceMarker — no prior red evidence exists (the hand step preceded the first certification); green certified from the passing target test with the vacuous-guard marker absent and the $behaviorId:hand attestation header present
- criterion: FR-003
- test: $testPath
- exit: 0
- at: 2026-08-30T00:00:00.000Z

''', mode: FileMode.append);
  }

  /// The attested test content the designed hand step leaves behind —
  /// the exact shape `make --born-green` demands (the `:hand`
  /// attestation header, the vacuous-guard marker absent) and the shape
  /// the operator's already-run certification proves.
  String attestedTestContent(String description) =>
      '${TddFixture.greenTest(description)}\n'
      '${handStepHeader(id)}\n';

  /// The #827 namespaced test path (the layout a real `gen` writes, and
  /// the path the driver's born-green probes resolve).
  String namespacedTestPath() =>
      p.join(fx.root.path, 'test', 'tdd', feature, 'contract_a7_test.dart');

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('U-1592-1 (issue #1592): a born-green-certified BLOCKED contract '
      'converges — the re-run re-enters at refactor ONLY and completes, '
      'instead of re-stopping at make not-certified-red and prescribing '
      'the already-run --born-green', () async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the declared contract holds',
        traces: 'FR-003',
        state: 'PENDING',
        kind: 'contract',
      ),
    ]);
    await fx.registerBehavior(
      id: id,
      description: 'the declared contract holds',
      testContent: attestedTestContent('the declared contract holds'),
      testPath: namespacedTestPath(),
    );
    // The state `zfa tdd run` parked: BLOCKED (the #1007 verdict).
    await fx.seedRunState(states: {id: 'blocked'});
    // The certification `make --born-green` wrote: green evidence on the
    // journal, backed by the attested test file on disk.
    await seedBornGreenEvidence(id, testPath: namespacedTestPath());
    // The real-world step transcripts on re-drive: verify-red grades the
    // already-passing contract test unexpected-green, and the flagless
    // make the driver spawns refuses not-certified-red (no red evidence
    // can exist for the lane / the born-green class). Pre-fix these
    // steps SPAWN; post-fix neither does.
    await fx.setStepOutcome('verify-red', id, 'unexpected-green');
    await fx.setStepOutcome('make', id, 'not-certified-red');

    final out = await drive();

    // THE LOOP (pre-#1592): the run stops at the #1411 arm and
    // prescribes `--born-green` — the command that already ran.
    expect(
      out,
      isNot(contains('--born-green` — then re-run')),
      reason: out,
    );
    expect(out, isNot(contains('is incomplete in tdd/cycle-log.md')),
        reason: out);
    expect(exitCode, 0, reason: out);
    // The convergent window: refactor ONLY — verify-red and make never
    // spawn for a born-green-certified blocked behavior.
    expect(fx.stepInvocations(), ['refactor $id'], reason: out);
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 '
        'green=1 done=0',
      ),
      reason: out,
    );
    // The green-only class ends GREEN by the pre-existing reconcile
    // design (bug #682) — the run COMPLETES, which is the #1592
    // acceptance; the next run re-enters at refactor and passes.
    final state = await readState();
    expect(state['behavior_states'][id], 'green', reason: out);

    // The loop-killer (the steady state, ported from the earlier B2
    // draft): the NEXT run re-enters at refactor ONLY — make (which
    // would refuse not-certified-red flagless) never re-spawns, and the
    // run completes with no manual command.
    fx.clearStepInvocations();
    final out2 = await drive();
    expect(out2, contains('result=complete'), reason: out2);
    expect(fx.stepInvocations(), ['refactor $id'], reason: out2);
    expect(out2, isNot(contains('--born-green` — then re-run')), reason: out2);
  });

  test('U-1592-2 (issue #1592 regression): a NORMAL blocked resume — no '
      'green evidence — keeps the exact pre-#1592 window: verify-red '
      're-drives, the #1007 verdict parks, result=blocked', () async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the declared contract holds',
        traces: 'FR-003',
        state: 'PENDING',
        kind: 'contract',
      ),
    ]);
    await fx.registerBehavior(
      id: id,
      description: 'the declared contract holds',
    );
    await fx.seedRunState(states: {id: 'blocked'});
    // No green evidence: the contract is still unsatisfied. The re-drive
    // re-grades the failing contract test BLOCKED (the honest verdict).
    await fx.setStepOutcome('verify-red', id, 'blocked');

    final out = await drive();

    expect(exitCode, 1, reason: out);
    expect(fx.stepInvocations(), ['verify-red $id'], reason: out);
    expect(
      out,
      contains('result=blocked pending=0 red=0 green=0 done=0 blocked=1'),
      reason: out,
    );
    expect(out, contains('stopped_at=$id:verify-red'), reason: out);
    final state = await readState();
    expect(state['behavior_states'][id], 'blocked', reason: out);
  });

  test('U-1592-3 (issue #1592 regression): green evidence WITHOUT its '
      'certified test file on disk keeps the exact pre-#1324 windows '
      '(the guard stays test-backed)', () async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the declared contract holds',
        traces: 'FR-003',
        state: 'PENDING',
        kind: 'contract',
      ),
    ]);
    await fx.registerBehavior(
      id: id,
      description: 'the declared contract holds',
      testContent: attestedTestContent('the declared contract holds'),
      testPath: namespacedTestPath(),
    );
    await fx.seedRunState(states: {id: 'blocked'});
    // The certified test file is GONE (the orphaned class): the green
    // evidence is NOT backed, so the guard must not fire.
    await seedBornGreenEvidence(
      id,
      testPath: '${namespacedTestPath()}.orphaned',
    );
    await fx.setStepOutcome('verify-red', id, 'unexpected-green');
    await fx.setStepOutcome('make', id, 'not-certified-red');

    final out = await drive();

    // The exact pre-#1592 stop: the #1411 arm, the re-drive window
    // (verify-red -> make) unchanged.
    expect(exitCode, 1, reason: out);
    expect(fx.stepInvocations(), ['verify-red $id', 'make $id'],
        reason: out);
    expect(out, contains('stopped_at=$id:hand'), reason: out);
    final state = await readState();
    expect(state['behavior_states'][id], 'blocked', reason: out);
  });

  test('U-1592-4 (issue #1592 regression, ported from the earlier B3 '
      'draft): a normal blocked resume whose re-drive certifies '
      'red-first completes the full ladder — the verify-red re-entry '
      'stands', () async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the declared contract holds',
        traces: 'FR-003',
        state: 'PENDING',
        kind: 'contract',
      ),
    ]);
    await fx.registerBehavior(
      id: id,
      description: 'the declared contract holds',
    );
    await fx.seedRunState(states: {id: 'blocked'});
    // No green evidence; the re-drive certifies the red honestly (the
    // contract test fails) and the ladder proceeds red-first.
    await fx.setStepOutcome('verify-red', id, 'ok');
    await fx.setStepOutcome('make', id, 'ok');

    final out = await drive();

    expect(out, contains('result=complete'), reason: out);
    expect(
      fx.stepInvocations(),
      contains('verify-red $id'),
      reason: 'without green evidence the blocked window is unchanged — '
          'verify-red re-entry stands (the hard constraint)',
    );
    expect(fx.stepInvocations(), contains('make $id'), reason: out);
  });

  test('U-1592-5 (issue #1592 regression, ported from the earlier B4 '
      'draft): unbacked green evidence against a drifting subject keeps '
      'the #1324 stale-artifacts stop and prescription', () async {
    await fx.seedTestList([
      (
        id: id,
        description: 'the declared contract holds',
        traces: 'FR-003',
        state: 'PENDING',
        kind: 'contract',
      ),
    ]);
    await fx.registerBehavior(
      id: id,
      description: 'the declared contract holds',
      writeTestFile: false,
    );
    await fx.seedRunState(states: {id: 'blocked'});
    // Plain green evidence (no born-green marker) whose certified test
    // file is GONE: unbacked, so the guard must not fire and the
    // re-drive walks into the #1324 stale-artifacts contradiction.
    await fx.seedGreenEvidence(id);
    await fx.setStepOutcome('verify-red', id, 'unexpected-green');
    await fx.setStepOutcome('make', id, 'subject-drift');

    final out = await drive();

    expect(
      fx.stepInvocations(),
      contains('verify-red $id'),
      reason: 'unbacked green evidence does not lift the blocked window — '
          'the #1324 SC-4 compat rule holds',
    );
    expect(out, contains('result=stale-artifacts'), reason: out);
    expect(out, contains('stopped_at=$id:make'), reason: out);
    expect(
      out,
      contains('--> fix: zfa tdd reset $feature'),
      reason: 'the #1324 prescription is unchanged',
    );
  });
}
