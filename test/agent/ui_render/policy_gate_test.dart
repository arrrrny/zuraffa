import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/policy_gate.dart';
import 'package:zuraffa/src/agent/ui_render/semantic_action.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('PolicyGate', () {
    test('safe-tier actions bypass the gate', () async {
      final gate = PolicyGate();
      const action = SemanticAction(actionId: 'tap_1', tier: ActionTier.safe);
      final result = await gate.intercept(action);
      expect(result, isNotNull);
      expect(result!.actionId, 'tap_1');
      expect(gate.pending, isEmpty);
    });

    test('policy_gate_blocks_confirm_tier_until_approved', () async {
      final gate = PolicyGate();
      const action = SemanticAction(actionId: 'buy', tier: ActionTier.confirm);

      // intercept returns a future that does NOT complete until the user
      // approves or denies.
      final future = gate.intercept(action);
      // Yield once to let any synchronous completion happen.
      await Future<void>.delayed(Duration.zero);
      expect(gate.pending, hasLength(1), reason: 'pending decision exists');
      expect(gate.pending.first.action.actionId, 'buy');

      // The future is not yet complete.
      bool completed = false;
      future.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse, reason: 'no decision yet');

      // Still pending — the action has not been delivered.
      expect(completed, isFalse);
    });

    test('policy_gate_allows_confirm_tier_after_approval', () async {
      final gate = PolicyGate();
      const action = SemanticAction(actionId: 'buy', tier: ActionTier.confirm);

      final future = gate.intercept(action);
      await Future<void>.delayed(Duration.zero);
      expect(gate.pending, hasLength(1));

      // Approve the latest pending decision.
      gate.approveLatest();
      final delivered = await future;

      expect(delivered, isNotNull);
      expect(delivered!.actionId, 'buy');
      expect(delivered.tier, ActionTier.confirm);
      expect(gate.pending, isEmpty, reason: 'decision consumed');
    });

    test('deny drops the action — delivered future resolves to null', () async {
      final gate = PolicyGate();
      const action = SemanticAction(actionId: 'buy', tier: ActionTier.confirm);

      final future = gate.intercept(action);
      gate.denyLatest();
      final delivered = await future;

      expect(delivered, isNull, reason: 'denied actions are dropped');
    });

    test('denyLatest is a no-op when nothing is pending', () async {
      final gate = PolicyGate();
      gate.denyLatest();
      gate.approveLatest();
      expect(gate.pending, isEmpty);
    });

    test(
      'cancel completes the future with null and removes from pending',
      () async {
        final gate = PolicyGate();
        const action = SemanticAction(
          actionId: 'buy',
          tier: ActionTier.confirm,
        );
        final future = gate.intercept(action);
        await Future<void>.delayed(Duration.zero);
        expect(gate.pending, hasLength(1), reason: 'decision is pending');

        // Host UI dismissed — cancel instead of approve/deny.
        gate.pending.first.cancel();
        final delivered = await future;

        expect(delivered, isNull, reason: 'cancelled decisions resolve null');
        expect(gate.pending, isEmpty, reason: 'cancelled decision removed');
      },
    );

    test('dispose cancels every pending decision (teardown)', () async {
      final gate = PolicyGate();
      final f1 = gate.intercept(
        const SemanticAction(actionId: 'a', tier: ActionTier.confirm),
      );
      final f2 = gate.intercept(
        const SemanticAction(actionId: 'b', tier: ActionTier.confirm),
      );
      await Future<void>.delayed(Duration.zero);
      expect(gate.pending, hasLength(2), reason: 'two decisions pending');

      gate.dispose();

      expect(await f1, isNull);
      expect(await f2, isNull);
      expect(gate.pending, isEmpty, reason: 'all decisions dropped');
    });
  });
}
