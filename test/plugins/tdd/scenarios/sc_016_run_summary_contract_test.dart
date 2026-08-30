@Tags(['slow'])
// SC-016 acceptance tests (spec 049-tdd-run, US4 / T020, SC-005/SC-006):
// the progress line and the final summary line form a stable machine
// contract — progress lines as steps complete (A10), the summary shape for
// every outcome class (A11), exit 0 exactly on complete-with-evidence
// (A12) — and a second concurrent run is refused without corrupting the
// state file.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-contract';
  Process? liveOwner;

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

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior',
        traces: 'FR-010',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-002',
        description: 'second behavior',
        traces: 'FR-010',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    liveOwner?.kill();
    liveOwner = null;
    exitCode = 0;
  });

  test(
    'A10: each completed step prints its progress line immediately',
    () async {
      final out = await drive();

      expect(exitCode, 0, reason: out);
      // FR-009: one progress line per completed step, in order.
      final positions = [
        out.indexOf('[run] B-001 gen -> ok'),
        out.indexOf('[run] B-001 verify-red -> certified'),
        out.indexOf('[run] B-001 make -> green'),
        out.indexOf('[run] B-001 refactor -> clean'),
        out.indexOf('[run] B-002 gen -> ok'),
        out.indexOf('[run] B-002 verify-red -> certified'),
        out.indexOf('[run] B-002 make -> green'),
        out.indexOf('[run] B-002 refactor -> clean'),
      ];
      expect(positions.every((p) => p >= 0), isTrue, reason: out);
      expect(positions, orderedEquals([...positions]..sort()));
      // Every [run] line in the output is one of the expected step lines.
      final runLines = RegExp(
        r'^\[run\] .+$',
        multiLine: true,
      ).allMatches(out).map((m) => m.group(0)!).toList();
      expect(runLines, hasLength(8));
    },
  );

  test(
    'A11: the summary line carries feature, result, counts, stopped_at',
    () async {
      // complete
      var out = await drive();
      expect(
        RegExp(
          '^run: feature=$feature result=complete '
          r'pending=\d+ red=\d+ green=\d+ done=\d+$',
          multiLine: true,
        ).hasMatch(out),
        isTrue,
        reason: out,
      );

      // stopped (with the stopping behavior and step)
      exitCode = 0;
      await File(fx.runStatePath).delete();
      await File(fx.cycleLogPath).delete();
      await fx.setStepOutcome('refactor', 'B-002', 'regression');
      out = await drive();
      expect(
        RegExp(
          '^run: feature=$feature result=stopped '
          r'pending=0 red=0 green=\d+ done=\d+ '
          r'stopped_at=B-002:refactor$',
          multiLine: true,
        ).hasMatch(out),
        isTrue,
        reason: out,
      );

      // corrupt-state
      exitCode = 0;
      await File(fx.runStatePath).writeAsString('not json at all');
      out = await drive();
      expect(
        RegExp(
          '^run: feature=$feature result=corrupt-state '
          r'pending=0 red=0 green=0 done=0$',
          multiLine: true,
        ).hasMatch(out),
        isTrue,
        reason: out,
      );

      // concurrent-run
      exitCode = 0;
      await File(fx.runStatePath).delete();
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRedEvidence('B-002');
      liveOwner = await Process.start('sleep', ['60']);
      await fx.seedRunState(
        states: {'B-001': 'done', 'B-002': 'red'},
        inFlightBehaviorId: 'B-002',
        inFlightStep: 'make',
        inFlightOwnerPid: liveOwner!.pid,
      );
      out = await drive();
      expect(
        RegExp(
          '^run: feature=$feature result=concurrent-run '
          r'pending=0 red=0 green=0 done=0$',
          multiLine: true,
        ).hasMatch(out),
        isTrue,
        reason: out,
      );
    },
  );

  test('A12: exit 0 occurs exactly on all-DONE-with-evidence', () async {
    // Complete run: exit 0.
    await drive();
    expect(exitCode, 0);

    // Stopped run: non-zero.
    exitCode = 0;
    await File(fx.runStatePath).delete();
    await File(fx.cycleLogPath).delete();
    await fx.setStepOutcome('gen', 'B-002', 'ownership-conflict');
    await drive();
    expect(exitCode, isNot(0));

    // Corrupt state: non-zero.
    exitCode = 0;
    await File(fx.runStatePath).writeAsString('[');
    await drive();
    expect(exitCode, isNot(0));

    // Concurrent run: non-zero.
    exitCode = 0;
    await File(fx.runStatePath).delete();
    liveOwner = await Process.start('sleep', ['60']);
    await fx.seedRunState(
      states: {'B-001': 'pending'},
      inFlightBehaviorId: 'B-001',
      inFlightStep: 'gen',
      inFlightOwnerPid: liveOwner!.pid,
    );
    await drive();
    expect(exitCode, isNot(0));
  });

  test(
    'SC-006: a second concurrent run is refused with zero state corruption',
    () async {
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRedEvidence('B-002');
      liveOwner = await Process.start('sleep', ['60']);
      await fx.seedRunState(
        states: {'B-001': 'done', 'B-002': 'red'},
        inFlightBehaviorId: 'B-002',
        inFlightStep: 'make',
        inFlightOwnerPid: liveOwner!.pid,
      );
      final stateBefore = await File(fx.runStatePath).readAsString();

      final out = await drive();

      expect(exitCode, isNot(0), reason: out);
      expect(out.toLowerCase(), contains('in flight'));
      // Refused before any work: no steps invoked, state file untouched.
      expect(fx.stepInvocations(), isEmpty);
      expect(await File(fx.runStatePath).readAsString(), stateBefore);
      expect(
        RegExp(
          '^run: feature=$feature result=concurrent-run '
          r'pending=0 red=0 green=0 done=0$',
          multiLine: true,
        ).hasMatch(out),
        isTrue,
        reason: out,
      );
    },
  );
}
