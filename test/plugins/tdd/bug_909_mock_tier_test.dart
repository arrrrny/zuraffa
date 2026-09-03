import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/run_state.dart';

void main() {
  group('Issue #909 - MOCKED tier & mock-default behavior state', () {
    test('BehaviorState includes mocked enum value', () {
      expect(BehaviorState.values.map((e) => e.name), contains('mocked'));
    });

    test('RunState serializes and deserializes mocked state', () {
      final state = RunState(
        feature: '001-mock-feature',
        behaviorStates: {'U1': BehaviorState.mocked},
      );
      final json = state.toJson();
      expect(json, contains('"U1":"mocked"'));

      final decoded = RunState.fromJson(json);
      expect(decoded.behaviorStates['U1'], equals(BehaviorState.mocked));
    });
  });
}
