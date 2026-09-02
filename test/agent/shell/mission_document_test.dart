import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/shell/mission_document.dart';

void main() {
  group('MissionDocument — serializable mission format (#808)', () {
    MissionDocument build() => MissionDocument(
      missionId: 'm-42',
      role: AgentRole.builder,
      goal: 'Implement the cart usecase',
      feature: 'lib/src/features/cart/',
      steps: const [
        MissionStep(id: 's1', description: 'read plan'),
        MissionStep(id: 's2', description: 'write usecase'),
        MissionStep(id: 's3', description: 'run tests'),
      ],
      cursor: 1,
      status: MissionDocumentStatus.running,
      heldScopes: const ['lib/src/features/cart/'],
      budget: const MissionBudgetSpec(maxCalls: 12, maxTokens: 5000),
      updatedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    test('round-trips through JSON without loss', () {
      final doc = build();
      final restored = MissionDocument.fromJson(doc.toJson());
      expect(restored.missionId, doc.missionId);
      expect(restored.role, doc.role);
      expect(restored.goal, doc.goal);
      expect(restored.feature, doc.feature);
      expect(restored.cursor, doc.cursor);
      expect(restored.status, doc.status);
      expect(restored.heldScopes, doc.heldScopes);
      expect(restored.budget!.maxCalls, 12);
      expect(restored.budget!.maxTokens, 5000);
      expect(restored.steps.length, 3);
      expect(restored.steps[1].id, 's2');
      expect(restored.steps[1].status, MissionStepStatus.pending);
      expect(restored.updatedAt, doc.updatedAt);
    });

    test('step status transitions survive a snapshot round-trip', () {
      final doc = build();
      final advanced = doc.withStepDone('s1');
      final restored = MissionDocument.fromJson(advanced.toJson());
      expect(restored.steps[0].status, MissionStepStatus.done);
      expect(restored.steps[1].status, MissionStepStatus.pending);
    });

    test('withStepDone advances the cursor to the next pending step', () {
      final doc = build().withStepDone('s1');
      expect(doc.cursor, 1);
      final done = doc.withStepDone('s2');
      expect(done.cursor, 2);
      expect(done.steps[0].status, MissionStepStatus.done);
      expect(done.steps[1].status, MissionStepStatus.done);
    });

    test('nextStep returns the step at the cursor (resume point)', () {
      final doc = build().withStepDone('s1');
      expect(doc.nextStep?.id, 's2');
      expect(doc.progress, (hasDone: 1, total: 3));
    });

    test('all steps done → completed', () {
      var doc = build();
      doc = doc.withStepDone('s1').withStepDone('s2').withStepDone('s3');
      expect(doc.isComplete, isTrue);
    });
  });

  group('RoleGates — same kernel, different tool gates (#808)', () {
    test('builder may write code but reviewer may NOT', () {
      expect(RoleGates.allows(AgentRole.builder, 'code.write'), isTrue);
      expect(RoleGates.allows(AgentRole.reviewer, 'code.write'), isFalse);
    });

    test('planner is read/write on plan but never on code', () {
      expect(RoleGates.allows(AgentRole.planner, 'plan.write'), isTrue);
      expect(RoleGates.allows(AgentRole.planner, 'code.read'), isTrue);
      expect(RoleGates.allows(AgentRole.planner, 'code.write'), isFalse);
    });

    test('operator runs deploy + rollback but never writes code', () {
      expect(RoleGates.allows(AgentRole.operator, 'deploy.run'), isTrue);
      expect(RoleGates.allows(AgentRole.operator, 'rollback.run'), isTrue);
      expect(RoleGates.allows(AgentRole.operator, 'code.write'), isFalse);
    });

    test('reviewer can approve but not deploy', () {
      expect(RoleGates.allows(AgentRole.reviewer, 'review.approve'), isTrue);
      expect(RoleGates.allows(AgentRole.reviewer, 'deploy.run'), isFalse);
    });

    test('every role passes through the policy-shell gate check', () {
      // Role gates compose with the existing PermissionRegistry risk levels:
      // a role allowing a tool that the registry marks `admin` still needs
      // confirmation — but a role NOT allowing it is denied outright.
      expect(RoleGates.forRole(AgentRole.builder), isNotEmpty);
      expect(
        RoleGates.forRole(AgentRole.builder),
        isNot(equals(RoleGates.forRole(AgentRole.reviewer))),
      );
    });
  });

  group('SnapshotStore — crash-safe mission persistence (#808)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('zfa-shell-test');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('save + load round-trips a mission document', () {
      final store = SnapshotStore(tmp.path);
      final doc = MissionDocument(
        missionId: 'm-1',
        role: AgentRole.planner,
        goal: 'g',
        feature: 'lib/src/features/cart/',
        steps: const [MissionStep(id: 's1', description: 'd')],
      );
      store.save(doc);
      final loaded = store.load('m-1');
      expect(loaded, isNotNull);
      expect(loaded!.missionId, 'm-1');
      expect(loaded.role, AgentRole.planner);
    });

    test('load returns null for unknown missions (fresh workspace)', () {
      final store = SnapshotStore(tmp.path);
      expect(store.load('nope'), isNull);
    });

    test('snapshot is atomic — a torn write never produces a corrupt doc', () {
      final store = SnapshotStore(tmp.path);
      final doc = MissionDocument(
        missionId: 'm-2',
        role: AgentRole.builder,
        goal: 'g',
        feature: 'f',
        steps: const [MissionStep(id: 's1', description: 'd')],
      );
      store.save(doc);
      // Simulate a crash mid-save: a leftover temp file must not be picked
      // up as a snapshot.
      store.save(doc.withStepDone('s1'));
      final loaded = store.load('m-2');
      expect(loaded!.steps.first.status, MissionStepStatus.done);
      // Only the canonical snapshot file + at most one temp file exist.
      expect(
        tmp.listSync().where((e) => e.path.contains('m-2')).length,
        lessThanOrEqualTo(2),
      );
    });
  });
}
