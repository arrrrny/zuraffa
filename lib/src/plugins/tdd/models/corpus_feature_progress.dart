/// Corpus-level per-feature progress model (spec 051-corpus-harness).
library;

import 'dart:convert';

/// Per-feature state in the corpus runner.
enum CorpusFeatureState {
  pending,
  driving,
  done,
  stopped,
  waived,
  notReady,
  dropped,
}

/// Explicit waiver record when a verify gate is waived.
class WaiverRecord {
  const WaiverRecord({
    required this.reason,
    required this.actor,
    required this.when,
  });

  factory WaiverRecord.fromJson(Map<String, dynamic> json) => WaiverRecord(
    reason: json['reason'] as String,
    actor: json['actor'] as String,
    when: json['when'] as String,
  );

  final String reason;
  final String actor;
  final String when;

  Map<String, dynamic> toJson() => {
    'reason': reason,
    'actor': actor,
    'when': when,
  };
}

/// Per-feature corpus progress.
class CorpusFeatureProgress {
  const CorpusFeatureProgress({
    required this.name,
    this.state = CorpusFeatureState.pending,
    this.gateOutcome,
    this.waived,
  });

  factory CorpusFeatureProgress.fromJson(
    String name,
    Map<String, dynamic> json,
  ) => CorpusFeatureProgress(
    name: name,
    state: CorpusFeatureState.values.byName(json['state'] as String),
    gateOutcome: json['gate_outcome'] as String?,
    waived: json['waived'] != null
        ? WaiverRecord.fromJson(json['waived'] as Map<String, dynamic>)
        : null,
  );

  final String name;
  final CorpusFeatureState state;
  final String? gateOutcome;
  final WaiverRecord? waived;

  Map<String, dynamic> toJson() => {
    'state': state.name,
    if (gateOutcome != null) 'gate_outcome': gateOutcome,
    if (waived != null) 'waived': waived!.toJson(),
  };

  CorpusFeatureProgress copyWith({
    CorpusFeatureState? state,
    String? gateOutcome,
    WaiverRecord? waived,
  }) => CorpusFeatureProgress(
    name: name,
    state: state ?? this.state,
    gateOutcome: gateOutcome ?? this.gateOutcome,
    waived: waived ?? this.waived,
  );
}

/// Aggregate corpus progress persisted at `.zfa/corpus/progress.json`.
class CorpusProgress {
  CorpusProgress({
    Map<String, CorpusFeatureProgress>? features,
    this.inFlight = false,
    this.ownerPid,
    this.startedAt,
    this.lastUpdatedAt,
  }) : features = features ?? {};

  factory CorpusProgress.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'] as Map<String, dynamic>? ?? {};
    final features = featuresRaw.map(
      (k, v) => MapEntry(
        k,
        CorpusFeatureProgress.fromJson(k, v as Map<String, dynamic>),
      ),
    );
    return CorpusProgress(
      features: features,
      inFlight: json['in_flight'] as bool? ?? false,
      ownerPid: json['owner_pid'] as int?,
      startedAt: json['started_at'] as String?,
      lastUpdatedAt: json['last_updated_at'] as String?,
    );
  }

  final Map<String, CorpusFeatureProgress> features;
  final bool inFlight;
  final int? ownerPid;
  final String? startedAt;
  final String? lastUpdatedAt;

  Map<String, dynamic> toJson() => {
    'features': features.map((k, v) => MapEntry(k, v.toJson())),
    'in_flight': inFlight,
    if (ownerPid != null) 'owner_pid': ownerPid,
    if (startedAt != null) 'started_at': startedAt,
    if (lastUpdatedAt != null) 'last_updated_at': lastUpdatedAt,
  };

  String toJsonString() {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
