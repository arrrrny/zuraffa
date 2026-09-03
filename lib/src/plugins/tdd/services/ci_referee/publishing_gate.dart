/// `PublishingGate` — the enforcement point (spec 070 US3) deciding
/// whether a build can be released as production or must be labeled as
/// simulation/demo:
///
/// - all features `complete(real)` → production (FR-004);
/// - any feature `complete(mocked)` (rest real, none intermediate) → a
///   labeled simulation/demo build is offered instead, and an unlabeled
///   production build is blocked (FR-005);
/// - any intermediate state (`realizing`, `pending`, `receipt-unknown`)
///   → non-releasable, no build offered (FR-015).
///
/// Zero false positives (SC-003): the gate never blocks an all-real
/// corpus and never passes any non-real state.
library;

import 'feature_provenance.dart';

enum GateOutcome {
  /// All features complete(real): releasable as production.
  production,

  /// Any feature complete(mocked): a labeled simulation/demo build only.
  simulation,

  /// Intermediate states present: non-releasable, no build offered.
  blocked,
}

class GateDecision {
  const GateDecision({
    required this.outcome,
    required this.blockers,
    required this.releasable,
    this.label,
  });

  final GateOutcome outcome;

  /// Features refusing the production intent (mocked or intermediate).
  final List<String> blockers;

  /// Whether the production intent may proceed.
  final bool releasable;

  /// The explicit build label for simulation decisions (US3.AC3).
  final String? label;

  /// The machine summary line (`gate: ... result=...`).
  String get summaryLine =>
      'gate: features=${blockers.isEmpty ? "all-real" : "non-real=${blockers.join(", ")}"} '
      'result=${outcome.name}'
      '${label == null ? "" : " label=$label"}';
}

class PublishingGate {
  const PublishingGate();

  /// Evaluate the corpus for a production release intent.
  GateDecision evaluate(List<FeatureProvenance> features) {
    // The gate's scope: driven features (the `shared` infrastructure
    // row is not a release feature).
    final driven = features.where((f) => f.feature != 'shared').toList();

    final intermediate = driven
        .where(
          (f) => switch (f.state) {
            FeatureRealizationState.realizing ||
            FeatureRealizationState.pending ||
            FeatureRealizationState.receiptUnknown => true,
            _ => false,
          },
        )
        .map((f) => f.feature)
        .toList();
    final mocked = driven
        .where((f) => f.state == FeatureRealizationState.completeMocked)
        .map((f) => f.feature)
        .toList();

    if (intermediate.isNotEmpty) {
      // FR-015: intermediate states are non-releasable — not even a
      // simulation build is offered.
      return GateDecision(
        outcome: GateOutcome.blocked,
        blockers: [...intermediate, ...mocked],
        releasable: false,
      );
    }
    if (mocked.isNotEmpty) {
      // FR-005: production is blocked; a labeled simulation/demo build
      // is offered instead.
      return GateDecision(
        outcome: GateOutcome.simulation,
        blockers: mocked,
        releasable: false,
        label: 'simulation/demo build (mocked: ${mocked.join(", ")})',
      );
    }
    // FR-004: all complete(real) — releasable as production.
    return const GateDecision(
      outcome: GateOutcome.production,
      blockers: [],
      releasable: true,
    );
  }
}
