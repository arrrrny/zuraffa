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

  Map<String, dynamic> toJson() => {'feature': feature, 'owner_pid': ownerPid};
}

/// Corpus progress: per-feature state + in-flight marker + dropped list.
///
/// A mutable state object the runner updates as it drives (persisted by
/// the store after every feature); the in-flight marker is cleared before
/// the final save.
class CorpusProgress {
  CorpusProgress({
    Map<String, FeatureProgress>? features,
    this.inFlight,
    List<String>? dropped,
  }) : features = features ?? {},
       dropped = dropped ?? [];

  final Map<String, FeatureProgress> features;
  CorpusInFlight? inFlight;
  List<String> dropped;

  /// Record [state] for [feature] (a new entry starts as pending).
  void updateFeature(String feature, FeatureProgress state) {
    features[feature] = state;
  }

  Map<String, dynamic> toJson() => {
    'features': features.map((k, v) => MapEntry(k, v.toJson())),
    if (inFlight != null) 'in_flight': inFlight!.toJson(),
    'dropped': dropped,
  };

  /// Decode the raw [decoded] JSON value (output of `jsonDecode`).
  /// Shape mismatches throw a [FormatException] naming the cause.
  static CorpusProgress fromJson(dynamic decoded) {
    Never bad(String cause) => throw FormatException('corpus progress: $cause');

    if (decoded is! Map) bad('top-level value is not an object');
    final map = decoded;
    final features = <String, FeatureProgress>{};
    final featuresRaw = map['features'];
    if (featuresRaw != null) {
      if (featuresRaw is! Map) bad('"features" is not an object');
      for (final entry in featuresRaw.entries) {
        final name = entry.key;
        if (name is! String || name.isEmpty) {
          bad('feature name is not a non-empty string');
        }
        final row = entry.value;
        if (row is! Map) bad('features["$name"] is not an object');
        final stateRaw = row['state'];
        if (stateRaw is! String) {
          bad('features["$name"].state is not a string');
        }
        final state = FeatureCorpusState.fromName(stateRaw);
        if (state == null) {
          bad('features["$name"].state "$stateRaw" is unknown');
        }
        final gate = row['gate'];
        if (gate != null && gate is! String) {
          bad('features["$name"].gate is not a string');
        }
        final stoppedAt = row['stopped_at'];
        if (stoppedAt != null && stoppedAt is! String) {
          bad('features["$name"].stopped_at is not a string');
        }
        CorpusWaiver? waiver;
        final waiverRaw = row['waiver'];
        if (waiverRaw != null) {
          if (waiverRaw is! Map) {
            bad('features["$name"].waiver is not an object');
          }
          final w = Map<String, dynamic>.from(waiverRaw);
          for (final field in ['feature', 'gate', 'reason', 'actor', 'at']) {
            if (w[field] is! String) {
              bad('features["$name"].waiver.$field is not a string');
            }
          }
          waiver = CorpusWaiver.fromJson(w);
        }
        features[name] = FeatureProgress(
          state: state,
          gate: gate as String?,
          stoppedAt: stoppedAt as String?,
          waiver: waiver,
        );
      }
    }
    CorpusInFlight? inFlight;
    final inFlightRaw = map['in_flight'];
    if (inFlightRaw != null) {
      if (inFlightRaw is! Map) bad('"in_flight" is not an object');
      final feature = inFlightRaw['feature'];
      final ownerPid = inFlightRaw['owner_pid'];
      if (feature is! String) bad('"in_flight".feature is not a string');
      if (ownerPid is! num) bad('"in_flight".owner_pid is not a number');
      inFlight = CorpusInFlight(feature: feature, ownerPid: ownerPid.toInt());
    }
    final droppedRaw = map['dropped'];
    if (droppedRaw != null && droppedRaw is! List) {
      bad('"dropped" is not a list');
    }
    final dropped = (droppedRaw as List? ?? const [])
        .whereType<String>()
        .toList();
    return CorpusProgress(
      features: features,
      inFlight: inFlight,
      dropped: dropped,
    );
  }
}
