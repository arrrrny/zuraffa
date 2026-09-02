import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/shell/agent_shell.dart';
import 'package:zuraffa/src/agent/shell/mission_document.dart';
import 'package:zuraffa/src/agent/shell/shell_protocol.dart';

typedef ShellRunner =
    Future<Object?> Function(
      MissionDocument doc,
      String stepId,
      bool Function() aborted,
    );

/// A recordable mission runner shared across shell "processes" so the test
/// can prove completed steps are never re-executed after a crash.
class TestRunner {
  final List<String> executed = [];
  final Map<String, Completer<void>> gates = {};

  ShellRunner get fn => (doc, stepId, aborted) async {
    final gate = gates[stepId];
    if (gate != null) await gate.future;
    // kill -9 boundary: a step in flight when the agent died never
    // completes — exactly the kernel CancelToken contract.
    if (aborted()) return null;
    executed.add(stepId);
    return 'ok-$stepId';
  };
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('zfa-shell-daemon');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  MissionDocument threeStepMission({
    MissionBudgetSpec? budget,
    String id = 'm-9',
  }) => MissionDocument(
    missionId: id,
    role: AgentRole.builder,
    goal: 'Ship the cart feature',
    feature: 'lib/src/features/cart/',
    steps: const [
      MissionStep(id: 's1', description: 'read plan'),
      MissionStep(id: 's2', description: 'write code'),
      MissionStep(id: 's3', description: 'run tests'),
    ],
    budget: budget,
  );

  Future<Map<String, Object?>?> waitForEvent(
    List<Map<String, Object?>> events,
    String type, {
    int tries = 400,
  }) async {
    for (var i = 0; i < tries; i++) {
      for (final e in events.reversed) {
        if (e['type'] == type) return e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return null;
  }

  group('AgentShell — NDJSON daemon protocol (#808)', () {
    test('hello is answered with hello.welcome', () async {
      final shell = AgentShell(snapshots: SnapshotStore(tmp.path));
      final inCtrl = StreamController<Map<String, Object?>>();
      final out = <Map<String, Object?>>[];
      final sub = shell.attach('agent-a', inCtrl.stream).listen(out.add);
      inCtrl.add(ShellProtocol.encode({'type': 'hello', 'agentId': 'agent-a'}));
      final welcome = await waitForEvent(out, 'hello.welcome');
      expect(welcome, isNotNull);
      expect(welcome!['agentId'], 'agent-a');
      await sub.cancel();
      await shell.dispose();
    });

    test(
      'lease.acquire grants, second agent is denied, release frees',
      () async {
        final shell = AgentShell(snapshots: SnapshotStore(tmp.path));
        final inA = StreamController<Map<String, Object?>>();
        final inB = StreamController<Map<String, Object?>>();
        final outA = <Map<String, Object?>>[];
        final outB = <Map<String, Object?>>[];
        final subA = shell.attach('agent-a', inA.stream).listen(outA.add);
        final subB = shell.attach('agent-b', inB.stream).listen(outB.add);

        inA.add(
          ShellProtocol.encode({
            'type': 'lease.acquire',
            'agentId': 'agent-a',
            'scope': 'lib/src/features/cart/',
          }),
        );
        final granted = await waitForEvent(outA, 'lease.granted');
        expect(granted, isNotNull);

        inB.add(
          ShellProtocol.encode({
            'type': 'lease.acquire',
            'agentId': 'agent-b',
            'scope': 'lib/src/features/cart/',
          }),
        );
        final denied = await waitForEvent(outB, 'lease.denied');
        expect(denied, isNotNull);
        expect((denied!['conflict'] as Map)['holderId'], 'agent-a');

        inA.add(
          ShellProtocol.encode({
            'type': 'lease.release',
            'agentId': 'agent-a',
            'scope': 'lib/src/features/cart/',
          }),
        );
        final released = await waitForEvent(outA, 'lease.released');
        expect(released, isNotNull);

        await subA.cancel();
        await subB.cancel();
        await shell.dispose();
      },
    );

    test('unknown message type answers with an error event', () async {
      final shell = AgentShell(snapshots: SnapshotStore(tmp.path));
      final inCtrl = StreamController<Map<String, Object?>>();
      final out = <Map<String, Object?>>[];
      final sub = shell.attach('agent-a', inCtrl.stream).listen(out.add);
      inCtrl.add(ShellProtocol.encode({'type': 'wat'}));
      final err = await waitForEvent(out, 'error');
      expect(err, isNotNull);
      await sub.cancel();
      await shell.dispose();
    });
  });

  group('AgentShell — budget meter events on the NDJSON stream (#808)', () {
    test('emits budget.tick per step and budget.breach + mission.failed on '
        'exhaustion', () async {
      final runner = TestRunner();
      final shell = AgentShell(
        snapshots: SnapshotStore(tmp.path),
        runner: runner.fn,
      );
      final inCtrl = StreamController<Map<String, Object?>>();
      final out = <Map<String, Object?>>[];
      final sub = shell.attach('agent-a', inCtrl.stream).listen(out.add)
        ..onError((_) {});

      inCtrl.add(
        ShellProtocol.encode({
          'type': 'mission.submit',
          'agentId': 'agent-a',
          'document': threeStepMission(
            budget: const MissionBudgetSpec(maxCalls: 2),
          ).toJson(),
        }),
      );

      final breach = await waitForEvent(out, 'budget.breach');
      expect(
        breach,
        isNotNull,
        reason: 'budget exhaustion must surface as budget.breach',
      );
      expect(breach!['dimension'], 'calls');

      final failed = await waitForEvent(out, 'mission.failed');
      expect(failed, isNotNull);

      // Ticks fired for the steps that ran.
      final ticks = out.where((e) => e['type'] == 'budget.tick').toList();
      expect(ticks, isNotEmpty);
      expect(ticks.first['missionId'], 'm-9');
      expect(ticks.first['remainingCalls'], isNotNull);

      // The breaching step never executed.
      expect(runner.executed, isNot(contains('s3')));
      await sub.cancel();
      await shell.dispose();
    });
  });

  group('AgentShell — ✅ kill -9 mid-mission, fresh agent resumes (#808)', () {
    test(
      'a brand-new shell + agent completes the mission from the snapshot',
      () async {
        final runner = TestRunner();
        runner.gates['s2'] = Completer<void>();
        final store = SnapshotStore(tmp.path);

        // ── Process 1: agent-a submits the mission and dies mid-step-2. ──
        final shellA = AgentShell(snapshots: store, runner: runner.fn);
        final inA = StreamController<Map<String, Object?>>();
        final outA = <Map<String, Object?>>[];
        final subA = shellA.attach('agent-a', inA.stream).listen(outA.add);
        inA.add(
          ShellProtocol.encode({
            'type': 'mission.submit',
            'agentId': 'agent-a',
            'document': threeStepMission().toJson(),
          }),
        );

        // Wait until step s1 is durably done (cursor advanced on disk).
        var snapshot = store.load('m-9');
        for (
          var i = 0;
          i < 400 && (snapshot == null || snapshot.cursor < 1);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          snapshot = store.load('m-9');
        }
        expect(snapshot, isNotNull);
        expect(snapshot!.cursor, 1, reason: 's1 must be durably done');

        // kill -9: NO graceful close, no release, no completion event.
        await shellA.kill();
        // Whatever the orphaned in-flight step does afterwards must NOT
        // touch the durable state.
        runner.gates['s2']!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(
          store.load('m-9')!.cursor,
          1,
          reason: 'nothing may advance after kill -9',
        );
        final executedBeforeKill = List<String>.from(runner.executed);
        await subA.cancel();

        // ── Process 2: a FRESH shell; a fresh agent resumes. ──
        final shellB = AgentShell(snapshots: store, runner: runner.fn);
        final inB = StreamController<Map<String, Object?>>();
        final outB = <Map<String, Object?>>[];
        final subB = shellB.attach('agent-b', inB.stream).listen(outB.add);
        inB.add(
          ShellProtocol.encode({
            'type': 'mission.resume',
            'agentId': 'agent-b',
            'missionId': 'm-9',
          }),
        );

        final resumed = await waitForEvent(outB, 'mission.resumed');
        expect(
          resumed,
          isNotNull,
          reason: 'fresh agent must be told the mission was resumed',
        );
        final resumedDoc = MissionDocument.fromJson(
          (resumed!['document'] as Map).cast<String, Object?>(),
        );
        expect(resumedDoc.cursor, 1);

        final completed = await waitForEvent(outB, 'mission.completed');
        expect(
          completed,
          isNotNull,
          reason: 'mission must complete after resume',
        );

        // Completed steps were NOT re-executed: s1 exactly once (before the
        // kill), s2 + s3 exactly once (after the resume).
        expect(runner.executed.where((s) => s == 's1').length, 1);
        expect(runner.executed.where((s) => s == 's2').length, 1);
        expect(runner.executed.where((s) => s == 's3').length, 1);
        expect(executedBeforeKill, ['s1']);

        final finalDoc = store.load('m-9')!;
        expect(finalDoc.isComplete, isTrue);
        expect(finalDoc.status, MissionDocumentStatus.completed);
        await subB.cancel();
        await shellB.dispose();
      },
    );

    test('resume of an already-completed mission replays nothing and '
        'reports completed', () async {
      final store = SnapshotStore(tmp.path);
      var doc = threeStepMission();
      doc = doc.withStepDone('s1').withStepDone('s2').withStepDone('s3');
      store.save(doc.withStatus(MissionDocumentStatus.completed));

      final shell = AgentShell(snapshots: store);
      final runner = TestRunner();
      final inCtrl = StreamController<Map<String, Object?>>();
      final out = <Map<String, Object?>>[];
      final sub = shell.attach('agent-c', inCtrl.stream).listen(out.add);
      inCtrl.add(
        ShellProtocol.encode({
          'type': 'mission.resume',
          'agentId': 'agent-c',
          'missionId': 'm-9',
        }),
      );
      final completed = await waitForEvent(out, 'mission.completed');
      expect(completed, isNotNull);
      expect(runner.executed, isEmpty);
      await sub.cancel();
      await shell.dispose();
    });

    test('resume of an unknown mission answers mission.not_found', () async {
      final shell = AgentShell(snapshots: SnapshotStore(tmp.path));
      final inCtrl = StreamController<Map<String, Object?>>();
      final out = <Map<String, Object?>>[];
      final sub = shell.attach('agent-c', inCtrl.stream).listen(out.add);
      inCtrl.add(
        ShellProtocol.encode({
          'type': 'mission.resume',
          'agentId': 'agent-c',
          'missionId': 'ghost',
        }),
      );
      final nf = await waitForEvent(out, 'mission.not_found');
      expect(nf, isNotNull);
      await sub.cancel();
      await shell.dispose();
    });
  });
}
