@Tags(['slow'])
// Bug #1696 — out-of-band `zfa tdd make` binds after a `zfa tdd reset` do
// not accumulate: every post-reset bind is reverted by the next run's
// reconciliation, so the run re-drives the previously bound behavior from
// gen and the bind is lost.
//
// Root cause: the run driver's reconciliation subtracts the tombstoned
// behavior ids from the cycle-log evidence UNCONDITIONALLY
// (`JournalReader.tombstonedBehaviors`). The reset tombstone is a
// per-behavior invalidation bounded by its timestamp — make's own re-drive
// probe (`_tombstonedReDrive`, issue #1331) already honors the bound — but
// the driver throws the timestamp away, so evidence recorded AFTER the
// reset (the operator's `zfa tdd make <id> --born-green` re-bind) is
// subtracted too. `zfa tdd run` then sees the bound behavior as pending and
// re-enters at gen, clobbering the hand-delta pair.
//
// Expected (the fix under test): a post-reset bind is authoritative again —
// the driver re-enters the behavior at refactor, exactly like a
// pre-reset bind.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/born_green.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1696-post-reset-bind';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  Future<String> drive() =>
      runCli(['run', feature, '--zfa-bin', fx.fakeZfaBin]);

  /// Seed a green-evidence entry exactly like the issue #1411
  /// `--born-green` transition appends it (the `- evidence:` field carries
  /// the born-green journal marker the refactor evidence check keys on).
  /// [at] pins the entry's timestamp.
  Future<void> seedBornGreenEvidence(
    String behaviorId, {
    required String at,
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
- evidence: $bornGreenEvidenceMarker — no prior red evidence exists (the
  hand step preceded the first certification); green certified from the
  passing target test with the vacuous-guard marker absent and the
  $behaviorId:hand attestation header present
- criterion: FR-003
- test: ${fx.testPathOf(behaviorId)}
- exit: 0
- at: $at

''', mode: FileMode.append);
  }

  /// A post-reset timestamp: strictly after the reset tombstone's
  /// `started_at` regardless of clock granularity.
  String postResetAt() =>
      DateTime.now().toUtc().add(const Duration(seconds: 2)).toIso8601String();

  /// Seed a red-evidence entry for [behaviorId] with an explicit [at] —
  /// the post-reset red re-certification an honest re-drive that stopped
  /// before `make` leaves behind (mirrors [seedBornGreenEvidence]).
  Future<void> seedRedEvidenceAt(
    String behaviorId, {
    required String at,
  }) async {
    final file = File(fx.cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (red)

- behavior: $behaviorId
- kind: red
- classification: assertionFailure
- criterion: FR-007
- test: ${fx.testPathOf(behaviorId)}
- exit: 1
- at: $at

''', mode: FileMode.append);
  }

  /// Seed a LEGACY schema-0 green-evidence entry: `- kind: green` with NO
  /// `- at:` line at all (the shape whose timestamp cannot be read).
  Future<void> seedGreenEvidenceNoAt(String behaviorId) async {
    final file = File(fx.cycleLogPath);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- criterion: FR-003
- test: ${fx.testPathOf(behaviorId)}
- exit: 0

''', mode: FileMode.append);
  }

  /// Blank the LAST reset tombstone's `started_at` to an unparseable
  /// string — the unreadable-timestamp corner `JournalReader` hands back
  /// as `at: null` while still reporting the invalidated ids.
  Future<void> corruptResetTombstoneStartedAt() async {
    final file = File('${fx.featureDir}/tdd/journal.json');
    final journal =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
    entries.lastWhere((e) => e['phase'] == 'reset')['started_at'] =
        'not-a-timestamp';
    await file.writeAsString(jsonEncode(journal));
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('issue #1696: a post-reset bind is honored — the run does not '
      're-drive the bound behavior from gen', () async {
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the U1 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    // The pre-reset completed drive: red + green evidence and a done state.
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(states: {'U1': 'done'});

    // THE RESET: drops the registry + run-state + artifacts and tombstones
    // U1 (the issue's step 4).
    final resetOut = await runCli(['reset', feature]);
    expect(exitCode, 0, reason: resetOut);
    expect(
      await File('${fx.featureDir}/tdd/journal.json').readAsString(),
      contains('"phase": "reset"'),
      reason: 'the reset tombstone is what invalidates the dropped evidence',
    );

    // THE POST-RESET BIND (the issue's out-of-band fix-line protocol):
    // the re-driven pair is registered again and the `make --born-green`
    // skip transition certifies green — evidence recorded AFTER the reset.
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await seedBornGreenEvidence('U1', at: postResetAt());

    final runOut = await drive();

    expect(exitCode, 0, reason: runOut);
    // Pre-fix the tombstone subtraction hides the post-reset green
    // evidence: U1 reconciles to pending and the run re-drives it from
    // gen — the reported "each skip-transition bind re-opens the
    // previously bound behavior".
    expect(
      fx.stepInvocations(),
      ['refactor U1'],
      reason:
          'the post-reset bind must be authoritative — U1 re-enters at '
          'refactor only, never at gen: $runOut',
    );
    expect(runOut, isNot(contains('gen U1')), reason: runOut);
    final state =
        jsonDecode(await File(fx.runStatePath).readAsString())
            as Map<String, dynamic>;
    expect(
      (state['behavior_states'] as Map)['U1'],
      'green',
      reason: 'the bound behavior accumulates as green: $runOut',
    );
  });

  test('issue #1696: post-reset binds accumulate — two binds both survive '
      'one dispatch', () async {
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the U1 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U2',
        description: 'the U2 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await fx.registerBehavior(id: 'U2', description: 'the U2 behavior');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRedEvidence('U2');
    await fx.seedGreenEvidence('U2');
    await fx.seedRunState(states: {'U1': 'done', 'U2': 'done'});

    final resetOut = await runCli(['reset', feature]);
    expect(exitCode, 0, reason: resetOut);

    // Both behaviors are re-bound after the reset (the issue's repeated
    // fix-line protocol): each post-reset bind must accumulate.
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await fx.registerBehavior(id: 'U2', description: 'the U2 behavior');
    await seedBornGreenEvidence('U1', at: postResetAt());
    await seedBornGreenEvidence('U2', at: postResetAt());

    final runOut = await drive();

    expect(exitCode, 0, reason: runOut);
    expect(
      fx.stepInvocations(),
      ['refactor U1', 'refactor U2'],
      reason:
          'both post-reset binds accumulate — neither re-opens from gen: '
          '$runOut',
    );
  });

  test('issue #1696: a post-reset RED entry survives — the run re-enters at '
      'make, never from gen', () async {
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the U1 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(states: {'U1': 'done'});

    final resetOut = await runCli(['reset', feature]);
    expect(exitCode, 0, reason: resetOut);

    // The post-reset RED re-certification — an honest re-drive that
    // stopped after verify-red, before `make`. Pre-fix the tombstone
    // subtraction drops it too, so U1 reconciles pending and re-drives
    // from gen (clobbering the partial work); post-fix the red evidence
    // survives and the behavior re-enters at make.
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await seedRedEvidenceAt('U1', at: postResetAt());

    final runOut = await drive();

    expect(exitCode, 0, reason: runOut);
    expect(
      fx.stepInvocations(),
      isNot(contains('gen U1')),
      reason:
          'a post-reset red entry must survive — no re-drive from gen: '
          '$runOut',
    );
    expect(
      fx.stepInvocations(),
      contains('make U1'),
      reason: 'the surviving red re-enters the behavior at make: $runOut',
    );
  });

  test('issue #1696: a legacy green entry with NO `- at:` stays invalidated '
      '(fail-closed)', () async {
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the U1 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(states: {'U1': 'done'});

    final resetOut = await runCli(['reset', feature]);
    expect(exitCode, 0, reason: resetOut);

    // A green entry whose timestamp cannot be read cannot prove it
    // postdates the reset — the pre-#1696 invalidation stands, so the
    // dropped behavior re-drives from gen (the #1264 phantom never
    // returns).
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await seedGreenEvidenceNoAt('U1');

    final runOut = await drive();

    expect(exitCode, 0, reason: runOut);
    expect(
      fx.stepInvocations(),
      contains('gen U1'),
      reason:
          'an untimestamped green entry stays invalidated — U1 must '
          're-drive from gen: $runOut',
    );
  });

  test('issue #1696: an unreadable reset-tombstone timestamp fails closed — '
      'it never resurrects the dropped evidence', () async {
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the U1 behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    await fx.seedRedEvidence('U1');
    await fx.seedGreenEvidence('U1');
    await fx.seedRunState(states: {'U1': 'done'});

    final resetOut = await runCli(['reset', feature]);
    expect(exitCode, 0, reason: resetOut);
    // The tombstone's ids parse but its reset time does not.
    await corruptResetTombstoneStartedAt();
    expect(
      await File('${fx.featureDir}/tdd/journal.json').readAsString(),
      contains('not-a-timestamp'),
      reason: 'the tombstone started_at was blanked to an unparseable value',
    );

    await fx.registerBehavior(id: 'U1', description: 'the U1 behavior');
    // A post-reset bind whose evidence WOULD be revived under a parseable
    // tombstone timestamp — the fail-closed corner keeps it invalidated.
    await seedBornGreenEvidence('U1', at: postResetAt());

    final runOut = await drive();

    expect(exitCode, 0, reason: runOut);
    expect(
      fx.stepInvocations(),
      contains('gen U1'),
      reason:
          'an unreadable tombstone timestamp must fail closed — U1 '
          're-drives from gen: $runOut',
    );
  });
}
