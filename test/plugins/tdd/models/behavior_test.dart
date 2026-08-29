// Tests for the Behavior model (spec 041-tdd-setup-plugin, U1-U2).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';

void main() {
  group('Behavior', () {
    test('equality is by id alone', () {
      final b1 = Behavior(
        id: 'A1',
        feature: 'f',
        kind: BehaviorKind.acceptance,
        description: 'foo',
        sourceCriterion: 'AC-1',
        target: 'lib/x.dart',
      );
      final b2 = Behavior(
        id: 'A1',
        feature: 'different',
        kind: BehaviorKind.unit,
        description: 'bar',
        sourceCriterion: 'FR-2',
        target: 'lib/y.dart',
      );
      expect(b1 == b2, isTrue);
      expect(b1.hashCode, b2.hashCode);
    });

    test('different ids are not equal', () {
      final b1 = Behavior(
        id: 'A1',
        feature: 'f',
        kind: BehaviorKind.acceptance,
        description: '',
        sourceCriterion: 'AC-1',
        target: '',
      );
      final b2 = Behavior(
        id: 'A2',
        feature: 'f',
        kind: BehaviorKind.acceptance,
        description: '',
        sourceCriterion: 'AC-2',
        target: '',
      );
      expect(b1 == b2, isFalse);
    });

    test('default state is pending', () {
      final b = Behavior(
        id: 'U1',
        feature: 'f',
        kind: BehaviorKind.unit,
        description: '',
        sourceCriterion: 'FR-1',
        target: '',
      );
      expect(b.state, BehaviorState.pending);
    });
  });
}
