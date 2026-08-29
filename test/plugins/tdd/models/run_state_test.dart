// Tests for the RunState model (spec 041-tdd-setup-plugin, U8-U9).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/run_state.dart';

void main() {
  group('RunState', () {
    test('advance returns an immutable copy with the updated state', () {
      final s = RunState(
        feature: 'f',
        behaviorStates: {'A1': BehaviorState.pending},
      );
      final s2 = s.advance('A1', BehaviorState.red);
      expect(s.behaviorStates['A1'], BehaviorState.pending,
          reason: 'original is not mutated');
      expect(s2.behaviorStates['A1'], BehaviorState.red);
      expect(s2.inFlightBehaviorId, isNull);
      expect(s2.inFlightStep, isNull);
    });

    test('markInFlight sets the in-flight markers', () {
      final s = RunState(
        feature: 'f',
        behaviorStates: {'A1': BehaviorState.red},
      );
      final s2 = s.markInFlight('A1', 'make');
      expect(s2.inFlightBehaviorId, 'A1');
      expect(s2.inFlightStep, 'make');
      expect(s2.behaviorStates['A1'], BehaviorState.red);
    });

    test('toJson and fromJson round-trip', () {
      final s = RunState(
        feature: '041-tdd-setup-plugin',
        behaviorStates: {
          'A1': BehaviorState.done,
          'A2': BehaviorState.red,
          'U1': BehaviorState.pending,
        },
        inFlightBehaviorId: 'A2',
        inFlightStep: 'make',
      );
      final json = s.toJson();
      final s2 = RunState.fromJson(json);
      expect(s2.feature, '041-tdd-setup-plugin');
      expect(s2.behaviorStates['A1'], BehaviorState.done);
      expect(s2.behaviorStates['A2'], BehaviorState.red);
      expect(s2.behaviorStates['U1'], BehaviorState.pending);
      expect(s2.inFlightBehaviorId, 'A2');
      expect(s2.inFlightStep, 'make');
    });

    test('empty state has no behaviors', () {
      final s = RunState.empty('f');
      expect(s.behaviorStates, isEmpty);
      expect(s.inFlightBehaviorId, isNull);
    });
  });
}
