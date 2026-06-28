import 'package:zuraffa/zuraffa.dart';

/// Bidirectional synchronization strategy.
///
/// Extends [PushOnlySyncStrategy] with the ability to pull remote changes
/// and merge them into local storage. Conflicts between local pending
/// changes and incoming remote data are resolved via a configurable
/// [_conflictResolver] callback (default: remote wins).
///
/// ## Conflict resolution
///
/// When [pullRemote] encounters a record that is [SyncStatus.pending] or
/// [SyncStatus.failed] locally, the conflict resolver is invoked with the
/// local and remote versions. The returned entity is saved to local storage.
///
/// - If the resolver returns the remote entity (default behavior), the
///   record is marked [SyncStatus.synced] — the local pending change is
///   discarded in favor of the remote version.
/// - If the resolver returns the local entity, the record remains pending
///   — the local change still needs to push on the next sync cycle.
///
/// ## Example (generated wiring)
///
/// ```dart
/// final strategy = BidirectionalSyncStrategy<Product>(
///   fetchLocal: (keys) => localDataSource.getByIds(keys),
///   fetchRemoteList: () => remoteDataSource.getAll(),
///   createRemote: (product) => remoteDataSource.create(product),
///   updateRemote: (product) => remoteDataSource.update(product),
///   deleteRemote: (id) => remoteDataSource.delete(id),
///   saveLocal: (product) => localDataSource.put(product),
///   keyResolver: (product) => product.id,
///   metadataStore: syncMetadataStore,
///   conflictResolver: (local, remote) {
///     // Last-write-wins by updatedAt
///     if (local == null) return remote;
///     return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
///   },
/// );
/// ```
class BidirectionalSyncStrategy<T> extends PushOnlySyncStrategy<T> {
  /// Fetches all records from the remote data source.
  final Future<List<T>> Function() _fetchRemoteList;

  /// Saves an entity to local storage (upsert).
  final Future<void> Function(T entity) _saveLocal;

  /// Resolves conflicts between local and remote versions of an entity.
  ///
  /// Called when a record is pending locally but also exists in the remote
  /// pull. Receives the local version (may be `null` if not found) and the
  /// remote version. Returns the winning version to persist locally.
  final T Function(T? local, T remote) _conflictResolver;

  BidirectionalSyncStrategy({
    required super.fetchLocal,
    required super.createRemote,
    required super.updateRemote,
    required super.deleteRemote,
    required super.keyResolver,
    required super.metadataStore,
    required Future<List<T>> Function() fetchRemoteList,
    required Future<void> Function(T entity) saveLocal,
    T Function(T? local, T remote)? conflictResolver,
    super.config,
  }) : _fetchRemoteList = fetchRemoteList,
       _saveLocal = saveLocal,
       _conflictResolver = conflictResolver ?? ((local, remote) => remote);

  @override
  Future<void> pullRemote({CancelToken? cancelToken}) async {
    logger.info('Pulling remote records');

    final remoteRecords = await _fetchRemoteList();
    logger.info('Pulled ${remoteRecords.length} remote records');

    for (final remote in remoteRecords) {
      cancelToken?.throwIfCancelled();

      final key = keyResolver(remote);
      final metadata = await metadataStore.get(key);

      if (metadata == null || metadata.status == SyncStatus.synced) {
        // Not tracked locally or already synced → accept remote directly
        await _saveLocal(remote);
        await metadataStore.put(
          key,
          SyncMetadata(
            status: SyncStatus.synced,
            operation: SyncOperation.update,
          ),
        );
      } else {
        // Pending or failed locally → conflict
        await _resolveConflict(key, remote, metadata, cancelToken);
      }
    }

    logger.info('Pull complete');
  }

  /// Resolve a conflict between a pending local record and its remote version.
  Future<void> _resolveConflict(
    String key,
    T remote,
    SyncMetadata metadata,
    CancelToken? cancelToken,
  ) async {
    // Fetch the local version to pass to the resolver
    final localEntities = await fetchLocal([key]);
    final local = localEntities.isEmpty ? null : localEntities.first;

    cancelToken?.throwIfCancelled();

    final resolved = _conflictResolver(local, remote);
    await _saveLocal(resolved);

    // If the resolver returned the remote version, the local pending
    // change is discarded → mark synced.
    // Otherwise, keep pending so the local change pushes on next cycle.
    if (identical(resolved, remote) || resolved == remote) {
      await metadataStore.put(
        key,
        SyncMetadata(
          status: SyncStatus.synced,
          operation: SyncOperation.update,
        ),
      );
      logger.fine('Conflict resolved for $key: remote wins');
    } else {
      logger.fine('Conflict resolved for $key: local wins, keeping pending');
    }
  }
}
