import 'sync_status.dart';
import 'sync_operation.dart';

/// Metadata record tracking the sync state of a single entity instance.
///
/// Stored in a [SyncMetadataStore] (separate Hive box), keyed by entity
/// identifier (`entity.id` if present, else `entity.hashCode`). This keeps
/// the domain entity pure — no sync infrastructure fields pollute it.
///
/// Fields:
/// - [status]: current sync state (pending/syncing/synced/failed)
/// - [retryCount]: number of failed sync attempts (reset on success)
/// - [lastAttemptAt]: when the last sync attempt occurred
/// - [lastError]: error message from last failed attempt
/// - [deletedAt]: tombstone timestamp (non-null = record was deleted locally)
/// - [operation]: what operation needs syncing (create/update/delete)
class SyncMetadata {
  final SyncStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime? deletedAt;
  final SyncOperation operation;

  const SyncMetadata({
    required this.status,
    required this.operation,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
    this.deletedAt,
  });

  /// Whether this record is a tombstone (deleted locally, pending remote delete).
  bool get isTombstone => deletedAt != null;

  SyncMetadata copyWith({
    SyncStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
    DateTime? deletedAt,
    SyncOperation? operation,
  }) {
    return SyncMetadata(
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      deletedAt: deletedAt ?? this.deletedAt,
      operation: operation ?? this.operation,
    );
  }

  @override
  String toString() =>
      'SyncMetadata(status: $status, operation: $operation, retryCount: $retryCount, '
      'deletedAt: $deletedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncMetadata &&
          status == other.status &&
          retryCount == other.retryCount &&
          operation == other.operation &&
          lastAttemptAt == other.lastAttemptAt &&
          lastError == other.lastError &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(
    status,
    retryCount,
    operation,
    lastAttemptAt,
    lastError,
    deletedAt,
  );
}
