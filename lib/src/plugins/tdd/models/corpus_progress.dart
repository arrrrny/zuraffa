/// Corpus progress models (spec 051-corpus-harness, data-model.md):
/// `FeatureCorpusState`, `FeatureProgress`, `CorpusWaiver`,
/// `CorpusProgress` (per-feature state + waiver records + in-flight
/// marker + dropped list), and the shared corrupt-state exception.
///
/// Persisted by `CorpusProgressStore` at `.zfa/corpus/progress.json`
/// after every completed feature; the resume source for `corpus run`.
library;

/// Raised when any corpus state file (progress, ledger, waivers,
/// carve-out) decodes to an unusable shape. The message names the file
/// and the recovery path (the corrupt-state stop, exit 3).
class CorpusCorruptException implements Exception {
  const CorpusCorruptException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Per-feature corpus state (data-model.md state table).
enum FeatureCorpusState {
  /// Manifest feature not yet driven.
  pending('pending'),

  /// In-flight (crash marker; resume re-enters it).
  driving('driving'),

  /// Loop complete AND verify gate passed (gate recorded).
  done('done'),

  /// Loop complete AND gate outcome explicitly waived (waiver recorded).
  waived('waived'),

  /// A roadblock stopped this feature (ledger entry exists).
  stopped('stopped');

  const FeatureCorpusState(this.name);

  /// Stable lowercase token persisted in progress JSON.
  final String name;

  static FeatureCorpusState? fromName(String? name) {
    if (name == null) return null;
    for (final state in FeatureCorpusState.values) {
      if (state.name == name) return state;
    }
    return null;
  }
}

/// A maintainer-authored verify-gate waiver (`.zfa/corpus/waivers.json`).
/// Exact-match only: the waiver covers ONE gate outcome for ONE feature
/// (FR-004; SC-002 — no silent absorptions).
class CorpusWaiver {
  const CorpusWaiver({
    required this.feature,
    required this.gate,
    required this.reason,
    required this.actor,
    required this.at,
  });

  final String feature;

  /// The gate label this waiver covers (`not_assessed`, …).
  final String gate;

  /// Why the gate outcome is accepted.
  final String reason;

  /// Who waived it.
  final String actor;

  /// ISO-8601 timestamp.
  final String at;

  Map<String, dynamic> toJson() => {
    'feature': feature,
    'gate': gate,
    'reason': reason,
    'actor': actor,
    'at': at,
  };

  static CorpusWaiver fromJson(Map<String, dynamic> json) => CorpusWaiver(
    feature: json['feature'] as String,
    gate: json['gate'] as String,
    reason: json['reason'] as String,
    actor: json['actor'] as String,
    at: json['at'] as String,
  );
}

/// One feature's persisted corpus progress.
class FeatureProgress {
  const FeatureProgress({
    required this.state,
    this.gate,
    this.stoppedAt,
    this.waiver,
  });

  final FeatureCorpusState state;

  /// The recorded verify gate label when evaluated (e.g. `pass`).
  final String? gate;

  /// The stop point when stopped: `<behavior>:<step>` from run's summary,
  /// or `verify` / `gate:<label>` for gate stops.
  final String? stoppedAt;

  /// Copied in full when a waiver applied (never silent).
  final CorpusWaiver? waiver;

  Map<String, dynamic> toJson() => {
    'state': state.name,
    if (gate != null) 'gate': gate,
    if (stoppedAt != null) 'stopped_at': stoppedAt,
    if (waiver != null) 'waiver': waiver!.toJson(),
  };
}

/// The corpus-level in-flight marker (FR-010 concurrency guard).
class CorpusInFlight {
  const CorpusInFlight({required this.feature, required this.ownerPid});

  final String feature;
  final int ownerPid;

  Map<String, dynamic> toJson() => {
    'feature': feature,
    'owner_pid': ownerPid,
  };
}

/// Corpus progress: per-feature state + in-flight marker + dropped list.
class CorpusProgress {
  CorpusProgress({
    Map<String, FeatureProgress>? features,
    this.inFlight,
    List<String>? dropped,
  })  : features = features ?? {},
        dropped = dropped ?? [];

  final Map<String, FeatureProgress> features;
  final CorpusInFlight? inFlight;
  final List<String> dropped;

  Map<String, dynamic> toJson() => {
    'features': features.map((k, v) => MapEntry(k, v.toJson())),
    if (inFlight != null) 'in_flight': inFlight!.toJson(),
    'dropped': dropped,
  };
}
