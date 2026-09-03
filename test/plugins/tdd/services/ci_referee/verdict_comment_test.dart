// US1 (spec 070): the PR verdict comment — feature × state table with the
// exit-protocol legend (FR-002), readable at a glance (US1.AC2), and the
// minimal doc-only verdict (FR-008).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/feature_provenance.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/verdict_comment.dart';

void main() {
  group('VerdictCommentRenderer (US1, FR-002)', () {
    late VerdictCommentRenderer renderer;

    setUp(() {
      renderer = const VerdictCommentRenderer();
    });

    test('A1: renders a row per feature with state, receipts, hand-delta and '
        'ratio, plus the exit-protocol legend', () {
      final comment = renderer.renderFull(
        features: [
          FeatureProvenance(
            feature: '010-cart',
            state: FeatureRealizationState.completeMocked,
            receiptCount: 4,
            handDeltaReceipts: 0,
            buckets: const ProvenanceBuckets(
              generated: 0,
              mock: 4,
              handDelta: 0,
              handWritten: 0,
            ),
            receiptVerified: true,
            receiptIds: const ['r-010-a', 'r-010-b'],
          ),
          FeatureProvenance(
            feature: '011-checkout',
            state: FeatureRealizationState.completeReal,
            receiptCount: 6,
            handDeltaReceipts: 0,
            buckets: const ProvenanceBuckets(
              generated: 6,
              mock: 0,
              handDelta: 0,
              handWritten: 0,
            ),
            receiptVerified: true,
            receiptIds: const ['r-011-a'],
          ),
          FeatureProvenance(
            feature: '012-search',
            state: FeatureRealizationState.completeReal,
            receiptCount: 3,
            handDeltaReceipts: 2,
            buckets: const ProvenanceBuckets(
              generated: 1,
              mock: 0,
              handDelta: 2,
              handWritten: 0,
            ),
            receiptVerified: true,
            receiptIds: const ['r-012-a', 'r-012-b'],
          ),
        ],
        gapLedger: GapLedgerSummary(
          found: 2,
          open: 1,
          blocking: const ['010-cart'],
        ),
        coverage: const CoverageMatrixSummary(
          features: 3,
          verified: 2,
          tiers: ['unit', 'integration'],
        ),
        result: 'gaps',
      );

      // The structured table header (FR-002).
      expect(comment, contains('## CI Referee Verdict'));
      expect(comment, contains('| Feature | State | Receipts |'));
      expect(comment, contains('| 010-cart |'));
      expect(comment, contains('mocked'));
      expect(comment, contains('| 011-checkout |'));
      expect(comment, contains('real'));
      expect(comment, contains('| 012-search |'));
      expect(comment, contains('2'));

      // The exit-protocol legend at the bottom explains every state
      // symbol (FR-002, US1.AC1).
      expect(comment, contains('Exit protocol'));
      expect(comment.toLowerCase(), contains('legend'));
      for (final legend in [
        'complete(real)',
        'complete(mocked)',
        'realizing',
        'receipt-unknown',
      ]) {
        expect(
          comment,
          contains(legend),
          reason: 'legend must explain $legend',
        );
      }

      // The verdict line is machine-parseable at the top.
      expect(comment, contains('verdict:'));
    });

    test('A2: a reviewer sees which features are releasable vs simulation-only '
        'from the state column alone', () {
      final comment = renderer.renderFull(
        features: [
          FeatureProvenance(
            feature: 'a-real',
            state: FeatureRealizationState.completeReal,
            receiptCount: 2,
            handDeltaReceipts: 0,
            buckets: const ProvenanceBuckets(
              generated: 2,
              mock: 0,
              handDelta: 0,
              handWritten: 0,
            ),
            receiptVerified: true,
            receiptIds: const ['r-a'],
          ),
          FeatureProvenance(
            feature: 'b-mocked',
            state: FeatureRealizationState.completeMocked,
            receiptCount: 2,
            handDeltaReceipts: 0,
            buckets: const ProvenanceBuckets(
              generated: 0,
              mock: 2,
              handDelta: 0,
              handWritten: 0,
            ),
            receiptVerified: true,
            receiptIds: const ['r-b'],
          ),
        ],
        gapLedger: GapLedgerSummary(found: 0, open: 0, blocking: const []),
        coverage: const CoverageMatrixSummary(
          features: 2,
          verified: 2,
          tiers: ['unit'],
        ),
        result: 'pass',
      );

      // Releasable marker: real state row; simulation marker: mocked row.
      expect(comment, contains('a-real'));
      expect(comment, contains('b-mocked'));
      // The legend must define the releasable / simulation distinction.
      expect(
        comment,
        contains('releasable'),
        reason: 'legend explains complete(real) = releasable',
      );
      expect(
        comment,
        contains('simulation'),
        reason: 'legend explains complete(mocked) = simulation-only',
      );
    });

    test('A3: a doc-only PR gets a minimal verdict with no feature table '
        '(FR-008)', () {
      final comment = renderer.renderMinimal(
        reason: 'no feature provenance was affected',
      );

      expect(comment, contains('## CI Referee Verdict'));
      expect(comment, contains('no feature provenance was affected'));
      // Minimal: no table, no legend, no wall of text.
      expect(comment, isNot(contains('| Feature |')));
      expect(
        comment.split('\n').where((l) => l.trim().isNotEmpty).length,
        lessThan(10),
      );
    });

    test('the shared/infrastructure row is rendered for non-feature code '
        '(edge case: unfeatureized code is not a gap)', () {
      final comment = renderer.renderFull(
        features: [
          FeatureProvenance(
            feature: 'shared',
            state: FeatureRealizationState.completeReal,
            receiptCount: 9,
            handDeltaReceipts: 9,
            buckets: const ProvenanceBuckets(
              generated: 0,
              mock: 0,
              handDelta: 9,
              handWritten: 3,
            ),
            receiptVerified: true,
            receiptIds: const ['r-shared'],
          ),
        ],
        gapLedger: GapLedgerSummary(found: 0, open: 0, blocking: const []),
        coverage: const CoverageMatrixSummary(
          features: 1,
          verified: 1,
          tiers: ['unit'],
        ),
        result: 'pass',
      );

      expect(comment, contains('shared'));
    });
  });
}
