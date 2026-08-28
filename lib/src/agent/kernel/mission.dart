import 'package:meta/meta.dart';

/// Composite key identifying a coalescable mission (FR-001).
///
/// Derived from: spark type + normalized value + country + strategy variant.
/// Two missions with the same key MUST coalesce within the configured
/// coalescing window.
@immutable
class MissionKey {
  MissionKey({
    required this.sparkType,
    required this.normalizedValue,
    required this.country,
    required this.strategyVariant,
  });

  /// The kind of spark that triggered the mission (e.g. `product_scan`,
  /// `price_check`).
  final String sparkType;

  /// Normalized (lowercased, trimmed, deduplicated) spark payload value.
  /// Normalization MUST happen before key construction so that two
  /// semantically-equivalent sparks produce the same key.
  final String normalizedValue;

  /// ISO-3166 country code (e.g. `US`, `DE`).
  final String country;

  /// Strategy variant identifier (e.g. `default`, `aggressive`). Two
  /// missions differing only here MUST NOT coalesce.
  final String strategyVariant;

  /// Stable string form, used as a Map key.
  late final String canonical = '$sparkType|$normalizedValue|$country|$strategyVariant';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionKey && other.canonical == canonical);

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => 'MissionKey($canonical)';
}

/// Status of a mission's lifecycle.
enum MissionStatus {
  /// Submitted, not yet executing.
  pending,

  /// Currently executing.
  running,

  /// Cancelled; partials salvaged.
  cancelled,

  /// Completed normally.
  completed,

  /// Failed (exception or tool error).
  failed,
}

/// Terminal outcome of a mission (one of `completed`, `cancelled_partial`,
/// `failed`, `cached_served`).
sealed class MissionOutcome {
  const MissionOutcome();
  String get label;
}

final class OutcomeCompleted extends MissionOutcome {
  const OutcomeCompleted(this.result);
  final Object? result;
  @override
  String get label => 'completed';
}

final class OutcomeCancelledPartial extends MissionOutcome {
  const OutcomeCancelledPartial(this.partials);
  final List<Object> partials;
  @override
  String get label => 'cancelled_partial';
}

final class OutcomeFailed extends MissionOutcome {
  const OutcomeFailed(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
  @override
  String get label => 'failed';
}

final class OutcomeCachedServed extends MissionOutcome {
  const OutcomeCachedServed(this.cached);
  final MissionOutcome cached;
  @override
  String get label => 'cached_served';
}

/// A unit of agent work submitted by a caller (FR-001).
class Mission {
  Mission({
    required this.id,
    required this.key,
    required this.callerId,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  final String id;
  final MissionKey key;
  final String callerId;
  final DateTime submittedAt;

  MissionStatus status = MissionStatus.pending;
  MissionOutcome? outcome;
  final List<Object> partials = <Object>[];

  /// Subscribers attached to this mission's event stream (other callers
  /// that coalesced onto this mission). The original caller is always
  /// present.
  final Set<String> subscriberIds = <String>{};

  bool get isActive =>
      status == MissionStatus.pending || status == MissionStatus.running;

  @override
  String toString() => 'Mission($id, key=$key, status=$status)';
}
