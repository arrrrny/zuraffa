# Contract: SyncStrategy Interface

**Feature**: 010-offline-first-sync | **Layer**: Domain (Core Library)

## Location

`lib/src/core/sync_strategy.dart` → exported via `lib/zuraffa.dart`

## Purpose

Defines the contract for how local changes are synchronized to a remote data source. Injected into sync-enabled repositories, analogous to how `CachePolicy` is injected into cached repositories.

## Interface

```dart
/// Strategy interface for offline-first synchronization.
///
/// Implementations define HOW local changes are pushed to remote
/// and HOW remote changes are pulled to local.
///
/// Injected into sync-enabled repositories alongside local/remote datasources.
///
/// Example implementations:
/// - [PushOnlySyncStrategy]: pushes local changes to remote (default)
/// - [BidirectionalSyncStrategy]: pushes local + pulls remote
abstract class SyncStrategy<T> {
  /// Push all pending local changes to the remote data source.
  ///
  /// Processes records with [SyncStatus.pending] or [SyncStatus.failed].
  /// Uses batching and retry with exponential backoff.
  /// Respects [cancelToken] for cancellation.
  Future<void> syncPending({CancelToken? cancelToken});

  /// Pull remote data and merge into local storage.
  ///
  /// Only meaningful for bidirectional strategies.
  /// Push-only strategies throw [UnimplementedError].
  Future<void> pullRemote({CancelToken? cancelToken});

  /// Get count of records pending sync.
  Future<int> getPendingCount();

  /// Get sync status for a specific record by key.
  Future<SyncStatus> getSyncStatus(String key);

  /// Mark a record as pending sync.
  ///
  /// Called by the repository after a local create or update.
  /// Records the operation type for the sync engine to use.
  Future<void> markPending(String key, {SyncOperation operation});

  /// Mark a record as deleted (tombstone).
  ///
  /// Called by the repository after a local delete.
  /// The record is hard-deleted from local storage;
  /// this metadata entry signals a pending remote delete.
  Future<void> markDeleted(String key);
}
```

## Dependencies

| Dependency | Direction | Purpose |
|------------|-----------|---------|
| `CancelToken` | Zuraffa core | Cancellation support |
| `SyncStatus` | Domain enum | Status tracking |
| `SyncOperation` | Domain enum | Operation type |

## Consumers

1. **Sync-enabled repository** (data layer) — calls `markPending()`, `markDeleted()`, delegates `syncPending()`, `pullRemote()`
2. **`Sync<Entity>UseCase`** (domain layer) — calls `syncPending()` via repository
3. **DI container** — registers strategy implementation as lazy singleton

## Implementations

| Implementation | Direction | Conflict Resolution | Use Case |
|----------------|-----------|---------------------|----------|
| `PushOnlySyncStrategy<T>` | Local → Remote | N/A | Default. Event tracking, analytics, fire-and-forget writes |
| `BidirectionalSyncStrategy<T>` | Local ↔ Remote | Configurable (default: remote-wins) | Collaborative data, shared state |
