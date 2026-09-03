/// `VerdictCommentRenderer` — renders the PR verdict comment (spec 070
/// US1, FR-002): the feature × state table with the exit-protocol legend,
/// the gap-ledger and coverage summaries, and the minimal doc-only
/// verdict (FR-008).
///
/// The comment is the primary interface between the CI referee and human
/// reviewers: a structured table that turns opaque CI pass/fail into
/// actionable provenance information. It must stay scannable — state
/// column readable at a glance (US1.AC2), legend explaining every symbol.
library;

import 'feature_provenance.dart';

class VerdictCommentRenderer {
  const VerdictCommentRenderer();

  /// Render the full verdict comment: header with the machine-parseable
  /// verdict line, the feature × state table (FR-002), the gap-ledger and
  /// coverage summaries (FR-013/FR-014), and the exit-protocol legend.
  String renderFull({
    required List<FeatureProvenance> features,
    required GapLedgerSummary gapLedger,
    required CoverageMatrixSummary coverage,
    required String result,
  }) {
    final verifiedCount = features.where((f) => f.receiptVerified).length;
    final buf = StringBuffer()
      ..writeln('## CI Referee Verdict')
      ..writeln()
      ..writeln(
        'verdict: $result — features: ${features.length} '
        'receipt-verified: $verifiedCount/${features.length} '
        'gaps: ${gapLedger.open} (blocking: ${gapLedger.blocking.length})',
      )
      ..writeln()
      ..writeln(
        '| Feature | State | Receipts | Hand-delta | G/M/H | Verified |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final f in features) {
      buf.writeln(
        '| ${f.feature} | ${f.state.label} | ${f.receiptCount} | '
        '${f.handDeltaReceipts} | ${f.ratioCell} | '
        '${f.receiptVerified ? 'yes' : 'unknown'} |',
      );
    }
    buf
      ..writeln()
      ..writeln('### Gap ledger')
      ..writeln()
      ..writeln(
        '${gapLedger.found} recorded, ${gapLedger.open} open, '
        '${gapLedger.blocking.length} blocking'
        '${gapLedger.blocking.isEmpty ? '' : ' — ${gapLedger.blocking.join(', ')}'}.',
      )
      ..writeln()
      ..writeln('### Coverage matrix')
      ..writeln()
      ..writeln(
        '${coverage.verified}/${coverage.features} features verified '
        'across tiers: ${coverage.tiers.join(', ')}.',
      )
      ..writeln()
      ..writeln('### Exit protocol (legend)')
      ..writeln()
      ..writeln(
        '- `complete(real)` — fully realized; releasable for '
        'production.',
      )
      ..writeln(
        '- `complete(mocked)` — simulation-only; ships as a labeled '
        'simulation/demo build, never production.',
      )
      ..writeln('- `realizing` — intermediate state; non-releasable.')
      ..writeln('- `pending` — not yet driven; non-releasable.')
      ..writeln(
        '- `receipt-unknown` — receipts missing or corrupt; '
        'provenance unproven, non-releasable.',
      )
      ..writeln(
        '- Receipts column counts receipts backing the feature; '
        'Hand-delta counts receipts recording hand modifications.',
      )
      ..writeln(
        '- G/M/H = generated/mock/hand-delta ratio over the '
        'feature\'s files.',
      );
    return buf.toString();
  }

  /// Render the minimal verdict for a PR that touches no feature code
  /// (US1.AC3, FR-008): no table, no legend — a clear statement that no
  /// feature provenance was affected, posted as success rather than
  /// failing the referee or posting an empty table.
  String renderMinimal({required String reason}) {
    return '## CI Referee Verdict\n\nverdict: pass (minimal) — $reason\n';
  }
}
