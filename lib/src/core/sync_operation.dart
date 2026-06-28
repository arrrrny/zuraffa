/// The type of operation that needs to be synced to remote.
///
/// Stored per-record in [SyncMetadata] so the [SyncStrategy] knows which
/// remote method to call (create, update, or delete).
enum SyncOperation {
  /// Entity was created locally, needs remote create.
  create,

  /// Entity was updated locally, needs remote update.
  update,

  /// Entity was deleted locally, needs remote delete (tombstone).
  delete,
}
