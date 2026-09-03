/// Feature provenance models (spec 070-ci-referee-provenance): the
/// realization state, the receipt-backed ratio buckets, the gap-ledger and
/// coverage summaries, and the per-feature provenance record the CI
/// referee's verdicts, rollups and gates all read.
///
/// The referee is a READ-ONLY view over the recorded infrastructure
/// (#807 receipt ledger, 051 corpus state, #832 simulation worlds): it
/// derives state, it never mutates it.
library;

/// The spec-070 realization state, read from recorded evidence.
///
/// Tokens match the spec's vocabulary: `complete(real)`,
/// `complete(mocked)`, `realizing`, `pending`, `receipt-unknown`.
enum FeatureRealizationState {
  /// Every registered behavior is green AND the feature's files trace to
  /// receipts with no simulation binding: fully realized, releasable.
  completeReal('complete(real)'),

  /// Every registered behavior is green AND the feature is bound to the
  /// certified simulation world (#832): simulation/demo only.
  completeMocked('complete(mocked)'),

  /// Partially driven (some behaviors green, corpus state `driving`):
  /// intermediate, non-releasable (FR-015).
  realizing('realizing'),

  /// Registered but never driven.
  pending('pending'),

  /// Receipts missing or corrupt for a feature that has artifacts — the
  /// rollup and verdict mark it rather than guess (FR-009).
  receiptUnknown('receipt-unknown');

  const FeatureRealizationState(this.label);

  /// The label rendered in tables and legends.
  final String label;

  /// Whether a production release may ship this state (FR-004/FR-015).
  bool get releasable => this == FeatureRealizationState.completeReal;

  /// Whether a labeled simulation/demo build may ship this state
  /// (FR-005: only fully-driven mocked features qualify).
  bool get simulationEligible => this == FeatureRealizationState.completeMocked;
}

/// Receipt-backed file buckets backing the ratios (SC-002: every count
/// traces to receipts).
class ProvenanceBuckets {
  const ProvenanceBuckets({
    required this.generated,
    required this.mock,
    required this.handDelta,
    required this.handWritten,
  });

  /// Receipt-covered files, unchanged since generation, real path.
  final int generated;

  /// Receipt-covered files, unchanged since generation, simulation-bound
  /// feature (#832).
  final int mock;

  /// Receipt-covered files whose on-disk digest drifted from the receipt
  /// (or cycle-log refactor `changed:` files): hand-delta receipts.
  final int handDelta;

  /// Files with no receipt backing at all (unprovenanced).
  final int handWritten;

  /// Files with receipt backing (generated + mock + handDelta).
  int get receiptBacked => generated + mock + handDelta;

  int get total => generated + mock + handDelta + handWritten;
}

/// The human-readable gap-ledger summary the verdict embeds (FR-013).
class GapLedgerSummary {
  const GapLedgerSummary({
    required this.found,
    required this.open,
    required this.blocking,
  });

  /// Total gap entries recorded (resolutions excluded).
  final int found;

  /// Unresolved gaps.
  final int open;

  /// Features named by unresolved, blocking gaps.
  final List<String> blocking;
}

/// The coverage-matrix summary the verdict embeds (FR-014).
class CoverageMatrixSummary {
  const CoverageMatrixSummary({
    required this.features,
    required this.verified,
    required this.tiers,
  });

  /// Features in the matrix.
  final int features;

  /// Features with at least one verified tier.
  final int verified;

  /// The tier labels the matrix tracked (unit, integration, …).
  final List<String> tiers;
}

/// One feature's provenance record: the verdict table's row source.
class FeatureProvenance {
  const FeatureProvenance({
    required this.feature,
    required this.state,
    required this.receiptCount,
    required this.handDeltaReceipts,
    required this.buckets,
    required this.receiptVerified,
    required this.receiptIds,
  });

  /// Feature directory name (`specs/<name>`), or `shared` for
  /// non-featureized infrastructure code (edge case).
  final String feature;

  final FeatureRealizationState state;

  /// Receipts backing the feature's provenance.
  final int receiptCount;

  /// Receipt entries recording hand deltas (drift or refactor changes).
  final int handDeltaReceipts;

  final ProvenanceBuckets buckets;

  /// SC-002: whether every counted file traces to a receipt.
  final bool receiptVerified;

  /// Receipt file names/ids backing the ratios (audit trail, US2.AC2).
  final List<String> receiptIds;

  /// Whether this state may ship as production (FR-004/FR-015).
  bool get releasable => state.releasable;

  /// The generated/mock/hand-delta ratio string for table cells.
  String get ratioCell {
    final total = buckets.total;
    if (total == 0) return 'n/a';
    final g = (buckets.generated * 100 / total).round();
    final m = (buckets.mock * 100 / total).round();
    final h = (buckets.handDelta * 100 / total).round();
    return '$g%/$m%/$h%';
  }
}
