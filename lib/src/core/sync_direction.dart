/// Sync direction for [SyncStrategy].
///
/// Determines whether sync is push-only (local → remote) or
/// bidirectional (local ↔ remote with conflict resolution).
enum SyncDirection {
  /// Push local changes to remote only.
  push,

  /// Push local changes AND pull remote changes.
  bidirectional,
}
