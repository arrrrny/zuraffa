/// Synchronization state of a single record in the sync metadata store.
///
/// Each locally-persisted record transitions through these states as the
/// [SyncStrategy] processes it:
///
/// ```mermaid
/// stateDiagram-v2
///     [*] --> pending: create/update/delete (local write)
///     pending --> syncing: sync triggered
///     syncing --> synced: remote confirms success
///     syncing --> pending: remote fails (retry < max)
///     syncing --> failed: retries exhausted
/// ```
enum SyncStatus {
  /// Written locally, not yet pushed to remote.
  pending,

  /// Currently being transmitted to remote.
  syncing,

  /// Successfully transmitted to remote.
  synced,

  /// Transmission failed after maximum retries.
  failed,
}
