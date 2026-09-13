@Tags(['slow'])
// Issue #1542 — born-green contracts can never complete a run.
//
// The structural trap: a contract-lane behavior wired through the
// born-green path (the `// zfa:tdd: <id>:hand` attestation + `zfa tdd
// make <id> --born-green`, issue #1411) earns green evidence honestly —
// but the run dead-ends at refactor with `refactor certified but
// evidence for "<id>" is incomplete in tdd/cycle-log.md (red: false,
// green: true)`. Contract-lane reds are BLOCKED-never-RED by design
// (issue #1007) and born-green certifications are green-WITHOUT-red by
// definition (issue #1411), so `red: true` is unobtainable for both
// classes. The refactor evidence check demanded it anyway.
//
// Fix under test (spec 1542-refactor-evidence-red-for-contract-lane):
//   driver (scripted fake zfa):
//     U-1542-1 — contract-lane behavior, green-only evidence → refactor
//                completes (red defined out of existence for the lane).
//     U-1542-2 — any-lane behavior whose LAST green entry carries the
//                born-green journal marker → refactor completes.
//     U-1542-3 — the marker-less twin (plain green-only, non-contract)
//                still misfires byte-identically (the bug #682 honesty
//                contract is unchanged).
//     U-1542-4 — the full born-green contract flow: `done` state (what
//                make's #1542 advancement leaves behind) + born-green
//                journal evidence reconciles to green and re-enters at
//                REFACTOR ONLY (make never re-spawns) and completes.
//   make block (real runner) lives in
//   commands/bug_1411_born_green_hand_transition_test.dart (M-1542-*).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1542-born-green-refactor';

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
  /// issue #1411 `--born-green` transition appends it: the `- evidence:`
  /// field carries the born-green journal marker (the shared
  /// `bornGreenEvidenceMarker` token) when [bornGreen] is true.
  Future<void> seedBornGreenEvidence(
    String behaviorId, {
    required bool bornGreen,
  }) async {
    final file = File(fx.cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    final evidence = bornGreen
        ? 'issue #1411 born-green hand transition — no prior red evidence '
            'exists (the hand step preceded the first certification); green '
            'certified from the passing target test with the vacuous-guard '
            'marker absent and the $behaviorId:hand attestation header '
            'present'
        : 'the target test passes against the implemented subject';
    await file.writeAsString(
      '''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- evidence: $evidence
- criterion: FR-003
- test: ${fx.testPathOf(behaviorId)}
- exit: 0
- at: 2026-08-30T00:00:00.000Z

''',
      mode: FileMode.append,
    );
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'U-1542-1 (issue #1542): a contract-lane behavior with green-only '
    'evidence completes the run — red is defined out of existence for the '
    'BLOCKED-never-RED lane (#1007)',
    () async {
      // The born-green contract shape after `make --born-green` certified
      // green: the behavior sits BLOCKED (the #1007 verdict — make was
      // never reached), the cycle-log carries the green certification,
      // and no red evidence can ever exist for the lane.
      await fx.seedTestList([
        (
          id: 'contract:A7',
          description: 'the declared contract holds',
          traces: 'FR-003',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
      await fx.registerBehavior(
        id: 'contract:A7',
        description: 'the declared contract holds',
      );
      await fx.seedRunState(states: {'contract:A7': 'blocked'});
      await seedBornGreenEvidence('contract:A7', bornGreen: false);
      // The re-entry scripts the honest already-green flip: verify-red
      // grades unexpected-green (the contract is satisfied now), make
      // re-certifies green without appending a duplicate entry, and
      // refactor certifies clean.
      await fx.setStepOutcome('verify-red', 'contract:A7', 'unexpected-green');
      await fx.setStepOutcome('make', 'contract:A7', 'ok-no-evidence');

      final out = await drive();

      // PRE-FIX the run dead-ends: `refactor certified but evidence for
      // "contract:A7" is incomplete in tdd/cycle-log.md (red: false,
      // green: true)` — the structural #1542 trap.
      expect(
        out,
        isNot(contains('is incomplete in tdd/cycle-log.md')),
        reason: out,
      );
      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), [
        'verify-red contract:A7',
        'make contract:A7',
        'refactor contract:A7',
      ], reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 '
          'green=0 done=1',
        ),
        reason: out,
      );
      final state = await readState();
      expect(state['behavior_states']['contract:A7'], 'done', reason: out);
    },
  );

  test(
    'U-1542-2 (issue #1542): a behavior whose LAST green entry carries the '
    'born-green journal marker completes refactor on green-only evidence — '
    'any lane',
    () async {
      // A UNIT behavior certified through the born-green transition (the
      // journal marker is on the last green entry): the lane is not
      // contract, so the exemption must come from the JOURNAL probe.
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(id: 'U1', description: 'first behavior');
      await fx.seedRunState(states: {'U1': 'green'});
      await seedBornGreenEvidence('U1', bornGreen: true);

      final out = await drive();

      expect(out, isNot(contains('is incomplete in tdd/cycle-log.md')),
          reason: out);
      expect(exitCode, 0, reason: out);
      // The green claim re-enters at refactor ONLY (never at make).
      expect(fx.stepInvocations(), ['refactor U1'], reason: out);
      final state = await readState();
      expect(state['behavior_states']['U1'], 'done', reason: out);
    },
  );

  test(
    'U-1542-3 (issue #1542): the marker-less twin — plain green-only, '
    'non-contract — still misfires with the byte-identical pre-#1542 '
    'message (the bug #682 honesty contract is unchanged)',
    () async {
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(id: 'U1', description: 'first behavior');
      await fx.seedRunState(states: {'U1': 'green'});
      await seedBornGreenEvidence('U1', bornGreen: false);

      final out = await drive();

      expect(
        out,
        contains(
          'refactor certified but evidence for "U1" is incomplete in '
          'tdd/cycle-log.md (red: false, green: true)',
        ),
        reason: out,
      );
      expect(exitCode, 2, reason: out);
      expect(
        out,
        contains(
          'result=runner-error pending=0 red=0 green=1 done=0 '
          'stopped_at=U1:refactor',
        ),
        reason: out,
      );
      final state = await readState();
      expect(state['behavior_states']['U1'], 'green', reason: out);
    },
  );

  test(
    'U-1542-4 (issue #1542): the full born-green contract flow — the '
    'post-advancement state reconciles to green and re-enters at refactor '
    'ONLY (make never re-spawns) — no manual run-state surgery',
    () async {
      // The state `make --born-green` leaves behind (the #1542
      // advancement: blocked -> done) plus the journal certification.
      // The reconciliation downgrades green-only `done` to `green`, and
      // the green claim re-enters at refactor — make (which would refuse
      // not-certified-red flagless) never spawns.
      await fx.seedTestList([
        (
          id: 'contract:A7',
          description: 'the declared contract holds',
          traces: 'FR-003',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
      await fx.registerBehavior(
        id: 'contract:A7',
        description: 'the declared contract holds',
      );
      await fx.seedRunState(states: {'contract:A7': 'done'});
      await seedBornGreenEvidence('contract:A7', bornGreen: true);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), ['refactor contract:A7'], reason: out);
      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 '
          'green=0 done=1',
        ),
        reason: out,
      );
      final state = await readState();
      expect(state['behavior_states']['contract:A7'], 'done', reason: out);
    },
  );
}
