// US3 (spec 070): the publishing gate — production only when every
// feature is complete(real) (FR-004); a labeled simulation/demo build
// when any feature is complete(mocked) (FR-005); intermediate states are
// non-releasable (FR-015). Zero false positives (SC-003).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/feature_provenance.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/publishing_gate.dart';

FeatureProvenance feature(String name, FeatureRealizationState state) =>
    FeatureProvenance(
      feature: name,
      state: state,
      receiptCount: 1,
      handDeltaReceipts: 0,
      buckets: const ProvenanceBuckets(
        generated: 1,
        mock: 0,
        handDelta: 0,
        handWritten: 0,
      ),
      receiptVerified: true,
      receiptIds: const ['r'],
    );

void main() {
  group('PublishingGate (US3, FR-004/005/015)', () {
    test('A7: an all-real corpus passes the production gate', () {
      final gate = const PublishingGate();
      final decision = gate.evaluate([
        feature('a', FeatureRealizationState.completeReal),
        feature('b', FeatureRealizationState.completeReal),
      ]);

      expect(decision.outcome, GateOutcome.production);
      expect(decision.releasable, isTrue);
      expect(decision.blockers, isEmpty);
      expect(decision.label, isNull, reason: 'production carries no label');
    });

    test('A8: one mocked feature blocks production and offers a labeled '
        'simulation build', () {
      final gate = const PublishingGate();
      final decision = gate.evaluate([
        feature('a', FeatureRealizationState.completeReal),
        feature('b', FeatureRealizationState.completeMocked),
      ]);

      expect(decision.outcome, GateOutcome.simulation);
      expect(decision.releasable, isFalse, reason: 'never labeled production');
      expect(decision.blockers, contains('b'));
      expect(
        decision.label,
        contains('simulation'),
        reason: 'the offered build is explicitly labeled',
      );
    });

    test('A9: a simulation build decision carries an explicit simulation '
        'label that distinguishes it from production', () {
      final gate = const PublishingGate();
      final decision = gate.evaluate([
        feature('a', FeatureRealizationState.completeMocked),
      ]);

      expect(decision.outcome, GateOutcome.simulation);
      expect(decision.label, isNotNull);
      expect(decision.label!.toLowerCase(), contains('simulation'));
      expect(decision.label!.toLowerCase(), isNot(contains('production')));
    });

    test('A10: realizing a feature flips the gate outcome on the next run '
        '(FR-015: intermediate states are non-releasable)', () {
      final gate = const PublishingGate();

      // Before: mocked corpus → simulation.
      final before = gate.evaluate([
        feature('a', FeatureRealizationState.completeMocked),
      ]);
      expect(before.outcome, GateOutcome.simulation);

      // The feature transitions mocked → realizing (mid `zfa tdd
      // realize`): intermediate, so not even a simulation build ships.
      final during = gate.evaluate([
        feature('a', FeatureRealizationState.realizing),
      ]);
      expect(during.outcome, GateOutcome.blocked);
      expect(during.releasable, isFalse);
      expect(during.label, isNull, reason: 'blocked decisions offer no build');

      // After: real corpus → production (the gate outcome updated).
      final after = gate.evaluate([
        feature('a', FeatureRealizationState.completeReal),
      ]);
      expect(after.outcome, GateOutcome.production);
    });

    test('SC-003: zero false positives — pending/receipt-unknown never pass '
        'and all-real never blocks', () {
      final gate = const PublishingGate();
      for (final state in [
        FeatureRealizationState.pending,
        FeatureRealizationState.receiptUnknown,
        FeatureRealizationState.realizing,
      ]) {
        final decision = gate.evaluate([
          feature('a', FeatureRealizationState.completeReal),
          feature('b', state),
        ]);
        expect(
          decision.outcome,
          GateOutcome.blocked,
          reason: '$state must never be releasable',
        );
        expect(decision.blockers, contains('b'));
      }

      // And a large all-real corpus never blocks.
      final allReal = gate.evaluate(
        List.generate(
          50,
          (i) => feature('f$i', FeatureRealizationState.completeReal),
        ),
      );
      expect(allReal.outcome, GateOutcome.production);
    });

    test('the machine summary line names every non-real feature', () {
      final gate = const PublishingGate();
      final decision = gate.evaluate([
        feature('alpha', FeatureRealizationState.completeMocked),
        feature('beta', FeatureRealizationState.realizing),
      ]);
      expect(decision.summaryLine, contains('alpha'));
      expect(decision.summaryLine, contains('beta'));
      expect(decision.summaryLine, startsWith('gate:'));
    });
  });
}
