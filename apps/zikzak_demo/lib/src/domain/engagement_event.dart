/// ZikZak engagement domain model (mock app — bug 501 remediation).
///
/// Mirrors the production ZikZak entity: a user-engagement observation
/// captured from a completed UseCase, persisted locally and queued for
/// background sync. Event types match spec 011 SC-005 exactly.
library;

/// The eight engagement event types ZikZak must record (spec 011 SC-005).
enum EngagementEventType {
  BARCODE_SCAN,
  LINK_SHARE,
  DEAL_LIKE,
  DEAL_SHARE,
  LISTING_SHARE,
  ASK_ZIKZAK,
  VISIT_LINK,
  SEARCH_TERM,
}

/// A single recorded user engagement, stored in the local Hive box and
/// flagged for background sync until acknowledged.
class EngagementEvent {
  EngagementEvent({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.synced = false,
  });

  /// Unique event identifier (derived from the UseCase invocation).
  final String id;

  /// The engagement category recorded for the completed UseCase.
  final EngagementEventType type;

  /// Domain payload extracted from the UseCase params (barcode number,
  /// query string, subject id, ...).
  final String payload;

  /// When the UseCase invocation started (from [HookContext.timestamp]).
  final DateTime createdAt;

  /// Whether the background sync has flushed this event to the backend.
  final bool synced;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'synced': synced,
  };

  factory EngagementEvent.fromJson(Map<String, dynamic> json) =>
      EngagementEvent(
        id: json['id'] as String,
        type: EngagementEventType.values.byName(json['type'] as String),
        payload: json['payload'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        synced: json['synced'] as bool? ?? false,
      );

  @override
  String toString() =>
      'EngagementEvent($type, payload: $payload, synced: $synced)';
}
