// SPEC 1568 — RunState carries the parked hand-step behavior ids.
//
// AC-4's persistence basis: the hand-step ids live in the feature's
// `tdd/run-state.json` (`hand_steps`) so a resume does not re-drive
// them. The field is ADDITIVE: a legacy snapshot without it loads with
// an empty set, and every existing JSON shape round-trips unchanged.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/run_state.dart';

void main() {
  group('B-1568-r1: RunState.handSteps round-trip', () {
    test('markHandStep adds the id immutably and preserves the states', () {
      final state = RunState.empty(
        '004-login-ui',
      ).advance('U1', BehaviorState.pending);
      final marked = state.markHandStep('U1');

      expect(marked.handSteps, contains('U1'));
      expect(
        state.handSteps,
        isNot(contains('U1')),
        reason: 'the original state is untouched (immutability)',
      );
      expect(
        marked.behaviorStates,
        state.behaviorStates,
        reason: 'the park never moves a behavior state',
      );
      expect(
        marked.inFlightBehaviorId,
        isNull,
        reason: 'the park clears the in-flight marker',
      );
    });

    test('toJson emits hand_steps; fromJson round-trips the ids', () {
      final state = RunState.empty(
        '004-login-ui',
      ).markHandStep('U1').markHandStep('U7');
      final json = state.toJson();

      expect(json, contains('hand_steps'));
      final restored = RunState.fromJson(json);
      expect(restored.handSteps, {'U1', 'U7'});
      expect(restored.feature, '004-login-ui');
    });

    test('a legacy snapshot WITHOUT hand_steps loads with an empty set '
        '(backward compatibility)', () {
      const legacyJson =
          '{"feature":"004-login-ui","behavior_states":{"U1":"pending"}}';
      final restored = RunState.fromJson(legacyJson);

      expect(restored.handSteps, isEmpty);
      expect(restored.behaviorStates['U1'], BehaviorState.pending);
    });

    test('markHandStep is idempotent for a known hand-step id', () {
      final marked = RunState.empty('f').markHandStep('U1').markHandStep('U1');
      expect(marked.handSteps, {'U1'});
    });
  });
}
