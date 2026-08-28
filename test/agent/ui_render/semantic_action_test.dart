import 'package:test/test.dart';
import 'package:zuraffa/src/agent/ui_render/semantic_action.dart';
import 'package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart';

void main() {
  group('SemanticAction', () {
    test('default tier is safe', () {
      const action = SemanticAction(actionId: 'tap_1');
      expect(action.tier, ActionTier.safe);
    });

    test('copyWith preserves unspecified fields', () {
      const action = SemanticAction(
        actionId: 'tap_1',
        tier: ActionTier.confirm,
        args: {'offerId': 42},
      );
      final updated = action.copyWith(viewId: 'v1');
      expect(updated.actionId, 'tap_1');
      expect(updated.tier, ActionTier.confirm);
      expect(updated.args, {'offerId': 42});
      expect(updated.viewId, 'v1');
    });
  });

  group('CapturingActionRouter', () {
    test('captured actions are observable', () {
      final router = CapturingActionRouter();
      const action = SemanticAction(actionId: 'tap_1');
      router.deliver(action);
      expect(router.delivered, hasLength(1));
      expect(router.delivered.first.actionId, 'tap_1');
    });
  });
}
