import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

/// Default push-only synchronization strategy.
///
/// Pushes local changes to a remote data source but does not pull remote
/// changes. Processes records with [SyncStatus.pending] or [SyncStatus.failed]
/// in batches of [SyncConfig.batchSize], with retry and exponential backoff
/// governed by [SyncConfig.maxRetries].
///
/// Tombstones (records marked for deletion) are processed first, before
/// live record synchronization.
///
/// ## Callback-based design
///
/// This strategy lives in the framework and cannot know about specific entity
/// types or datasource interfaces. Instead, it accepts callback functions
/// that the generated code wires up at runtime:
///
/// - [_fetchLocal]: reads local entities by key
/// - [_createRemote]: creates an entity on the remote
/// - [_updateRemote]: updates an entity on the remote
/// - [_deleteRemote]: deletes an entity from the remote by key
/// - [_keyResolver]: extracts the sync key from an entity
///
/// ## Example (generated wiring)
///
/// ```dart
/// final strategy = PushOnlySyncStrategy<Product>(
///   fetchLocal: (keys) => localDataSource.getByIds(keys),
///   createRemote: (product) => remoteDataSource.create(product),
///   updateRemote: (product) => remoteDataSource.update(product),
///   deleteRemote: (id) => remoteDataSource.delete(id),
///   keyResolver: (product) => product.id,
///   metadataStore: syncMetadataStore,
/// );
/// ```
class PushOnlySyncStrategy<T> extends SyncStrategy<T> with Loggable {
  /// Fetches local entities by their sync keys.
  final Future<List<T>> Function(List<String> keys) _fetchLocal;

  /// Creates an entity on the remote data source.
  final Future<T> Function(T entity) _createRemote;

  /// Updates an entity on the remote data source.
  final Future<T> Function(T entity) _updateRemote;

  /// Deletes an entity from the remote data source by key.
  final Future<void> Function(String key) _deleteRemote;

  /// Resolves the sync key from an entity (typically `entity.id`).
  final String Function(T entity) _keyResolver;

  /// Hive-backed metadata store tracking sync state per record.
  final SyncMetadataStore _metadataStore;

  /// Sync configuration: batch size, retry limits, backoff.
  final SyncConfig _config;

  PushOnlySyncStrategy({
    required Future<List<T>> Function(List<String> keys) fetchLocal,
    required Future<T> Function(T entity) createRemote,
    required Future<T> Function(T entity) updateRemote,
    required Future<void> Function(String key) deleteRemote,
    required String Function(T entity) keyResolver,
    required SyncMetadataStore metadataStore,
    SyncConfig config = const SyncConfig(),
  }) : _fetchLocal = fetchLocal,
       _createRemote = createRemote,
       _updateRemote = updateRemote,
       _deleteRemote = deleteRemote,
       _keyResolver = keyResolver,
       _metadataStore = metadataStore,
       _config = config;

  @override
  Future<void> syncPending({CancelToken? cancelToken}) async {
    // Gather only pending (fresh, never-failed) records.
    // Failed records are not retried here — use [syncFailed] for that.
    final pendingKeys = await _metadataStore.getKeysByStatus(
      SyncStatus.pending,
    );

    if (pendingKeys.isEmpty) {
      logger.fine('No pending records to sync');
      return;
    }

    logger.info('Syncing ${pendingKeys.length} pending records');
    await _processKeys(pendingKeys, cancelToken);
  }

  @override
  Future<void> syncFailed({CancelToken? cancelToken}) async {
    // Reset all failed records to pending with fresh retry counts.
    // This gives them a clean slate on the next sync cycle.
    final failedKeys = await _metadataStore.getKeysByStatus(SyncStatus.failed);

    if (failedKeys.isEmpty) {
      logger.fine('No failed records to retry');
      return;
    }

    logger.info('Retrying ${failedKeys.length} failed records');
    for (final key in failedKeys) {
      final metadata = await _metadataStore.get(key);
      if (metadata != null) {
        await _metadataStore.put(
          key,
          metadata.copyWith(status: SyncStatus.pending, retryCount: 0),
        );
      }
    }

    // Now process them through the same pipeline as pending records.
    await _processKeys(failedKeys, cancelToken);
  }

  /// Shared processing pipeline: partition keys into tombstones and live
  /// records, then process tombstones first, then live records in batches.
  ///
  /// The partition reads its metadata in one snapshot
  /// ([SyncMetadataStore.getByKeys]) instead of one awaited read per record.
  /// That snapshot only classifies the keys: [_syncBatch] re-reads its own
  /// batch, so a long pass can never push a status built from metadata that
  /// is several batches old (issue #2028).
  Future<void> _processKeys(List<String> keys, CancelToken? cancelToken) async {
    final metadataByKey = await _metadataStore.getByKeys(keys);

    final tombstoneKeys = <String>[];
    final liveKeys = <String>[];

    for (final key in keys) {
      final metadata = metadataByKey[key];
      if (metadata != null && metadata.isTombstone) {
        tombstoneKeys.add(key);
      } else {
        liveKeys.add(key);
      }
    }

    // Process tombstones first (remote deletes)
    for (final key in tombstoneKeys) {
      cancelToken?.throwIfCancelled();
      await _syncTombstone(key);
    }

    // Process live records in batches
    for (var i = 0; i < liveKeys.length; i += _config.batchSize) {
      cancelToken?.throwIfCancelled();

      final batchEnd = (i + _config.batchSize).clamp(0, liveKeys.length);
      final batchKeys = liveKeys.sublist(i, batchEnd);

      await _syncBatch(batchKeys, cancelToken);
    }

    logger.info('Sync processing complete');
  }

  /// Push a single tombstone (remote delete) and clean up metadata.
  Future<void> _syncTombstone(String key) async {
    try {
      await _deleteRemote(key);
      await _metadataStore.remove(key);
      logger.fine('Deleted remote record: $key');
    } catch (e) {
      logger.warning('Failed to delete remote record $key: $e');
      await _handleFailure(key, e);
    }
  }

  /// Sync a batch of live records: mark syncing, fetch local, push remote.
  ///
  /// The batch's metadata is re-read here instead of being reused blindly from
  /// the pass snapshot, so a `markDeleted`/`syncFailed` that landed while
  /// earlier batches ran is seen rather than overwritten by a status built
  /// from stale metadata. One awaited read per batch keeps the batching win
  /// while bounding the stale window to a single batch.
  ///
  /// Metadata I/O is batched: the `syncing` marks land in one
  /// [SyncMetadataStore.putAll], and the batch's terminal transitions — both
  /// `synced` results and the `failed`/`pending` retry updates, which used to
  /// cost one awaited write per failed record — in another. That terminal
  /// flush runs in a `finally`, so a cancellation after *k* successful pushes
  /// still persists that completed prefix: `syncing` is never rescanned by any
  /// pass, so a dropped write would strand those records unretried and
  /// uncounted (issue #2028).
  Future<void> _syncBatch(
    List<String> batchKeys,
    CancelToken? cancelToken,
  ) async {
    final metadataByKey = await _metadataStore.getByKeys(batchKeys);

    // Mark the batch's live records as syncing with a single box write.
    // Tombstones created since the partition and untracked keys are left
    // untouched — overwriting a tombstone with `syncing` would silently drop
    // its pending remote delete.
    final syncingUpdates = <String, SyncMetadata>{};
    for (final key in batchKeys) {
      final metadata = metadataByKey[key];
      if (metadata != null && !metadata.isTombstone) {
        syncingUpdates[key] = metadata.copyWith(status: SyncStatus.syncing);
      }
    }
    if (syncingUpdates.isEmpty) {
      return;
    }
    await _metadataStore.putAll(syncingUpdates);

    // Fetch local entities for this batch
    final entities = await _fetchLocal(batchKeys);

    // Push each entity to remote, collecting every terminal status transition
    // (`synced`, or the `failed`/`pending` result of a failure) so they land
    // in a single box write at the end of the batch.
    final statusUpdates = <String, SyncMetadata>{};
    try {
      for (final entity in entities) {
        cancelToken?.throwIfCancelled();
        final key = _keyResolver(entity);
        final metadata = metadataByKey[key];

        if (metadata == null || metadata.isTombstone) {
          logger.fine('Skipping record $key: no live metadata');
          continue;
        }

        try {
          if (metadata.operation == SyncOperation.create) {
            await _createRemote(entity);
          } else {
            await _updateRemote(entity);
          }

          // Success: fresh metadata, reset retry state
          statusUpdates[key] = SyncMetadata(
            status: SyncStatus.synced,
            operation: metadata.operation,
            lastAttemptAt: DateTime.now(),
          );
          logger.fine('Synced record: $key');
        } catch (e) {
          logger.warning('Failed to sync record $key: $e');
          final failure = _failureMetadata(key, e, metadata);
          if (failure != null) {
            statusUpdates[key] = failure;
          }
        }
      }
    } finally {
      // Flush even on cancellation: the records pushed so far are already on
      // the remote, so their `synced` transitions must not be lost.
      if (statusUpdates.isNotEmpty) {
        await _metadataStore.putAll(statusUpdates);
      }
    }

    // Handle keys whose entities were not found locally. Only records this
    // batch actually claimed are removed: a key that became a tombstone in
    // the meantime keeps its metadata for the next pass.
    final fetchedKeys = entities.map(_keyResolver).toSet();
    for (final key in syncingUpdates.keys) {
      if (!fetchedKeys.contains(key)) {
        logger.warning(
          'Record $key was pending but not found in local storage; '
          'removing metadata',
        );
        await _metadataStore.remove(key);
      }
    }
  }

  /// Compute the metadata a failed sync attempt leaves behind.
  ///
  /// Returns `null` when the record has no tracked metadata. This does not
  /// write: batch callers collect the result and land it with one
  /// [SyncMetadataStore.putAll], so a batch the remote rejects entirely costs
  /// a single write instead of one per record (issue #2028).
  ///
  /// If retries are exhausted, the record is marked [SyncStatus.failed].
  /// Otherwise it goes back to [SyncStatus.pending] for the next cycle.
  SyncMetadata? _failureMetadata(
    String key,
    Object error,
    SyncMetadata? metadata,
  ) {
    if (metadata == null) return null;

    final newRetryCount = metadata.retryCount + 1;
    final now = DateTime.now();
    final errorMsg = error.toString();

    if (newRetryCount >= _config.maxRetries) {
      logger.warning(
        'Record $key marked as failed after $newRetryCount retries',
      );
      return metadata.copyWith(
        status: SyncStatus.failed,
        retryCount: newRetryCount,
        lastAttemptAt: now,
        lastError: errorMsg,
      );
    }
    return metadata.copyWith(
      status: SyncStatus.pending,
      retryCount: newRetryCount,
      lastAttemptAt: now,
      lastError: errorMsg,
    );
  }

  /// Handle a sync failure for a single record: increment retry, apply
  /// backoff-aware status, persist it immediately.
  ///
  /// Used by the one-key-at-a-time tombstone path; batches use
  /// [_failureMetadata] and flush their collected updates with one `putAll`.
  Future<void> _handleFailure(
    String key,
    Object error, [
    SyncMetadata? existing,
  ]) async {
    final metadata = existing ?? await _metadataStore.get(key);
    final failure = _failureMetadata(key, error, metadata);
    if (failure != null) {
      await _metadataStore.put(key, failure);
    }
  }

  @override
  Future<void> markPending(
    String key, {
    SyncOperation operation = SyncOperation.create,
  }) async {
    await _metadataStore.put(
      key,
      SyncMetadata(status: SyncStatus.pending, operation: operation),
    );
    _maybeAutoSync();
  }

  @override
  Future<void> markDeleted(String key) async {
    await _metadataStore.put(
      key,
      SyncMetadata(
        status: SyncStatus.pending,
        operation: SyncOperation.delete,
        deletedAt: DateTime.now(),
      ),
    );
    _maybeAutoSync();
  }

  /// If [autoSync] is enabled, fire a background sync (fire-and-forget).
  ///
  /// Uses [unawaited] so the caller — typically a repository write method —
  /// returns immediately without waiting for the sync to complete.
  void _maybeAutoSync() {
    if (!_config.autoSync) return;
    logger.fine('autoSync triggered, syncing pending records');
    unawaited(syncPending());
  }

  @override
  Future<int> getPendingCount() async {
    final pending = await _metadataStore.countByStatus(SyncStatus.pending);
    final failed = await _metadataStore.countByStatus(SyncStatus.failed);
    return pending + failed;
  }

  @override
  Future<SyncStatus> getSyncStatus(String key) async {
    final metadata = await _metadataStore.get(key);
    return metadata?.status ?? SyncStatus.synced;
  }

  @override
  Future<void> pullRemote({CancelToken? cancelToken}) {
    throw UnimplementedError(
      'pullRemote is not supported by PushOnlySyncStrategy. '
      'Use BidirectionalSyncStrategy for bidirectional sync.',
    );
  }

  // ------------------------------------------------------------------
  // Protected accessors for subclasses (e.g. BidirectionalSyncStrategy).
  // Private fields are library-scoped in Dart, so subclasses in other
  // files cannot access _-prefixed members directly.
  // ------------------------------------------------------------------

  /// Protected: fetch local entities by keys.
  @protected
  Future<List<T>> Function(List<String> keys) get fetchLocal => _fetchLocal;

  /// Protected: resolve sync key from an entity.
  @protected
  String Function(T entity) get keyResolver => _keyResolver;

  /// Protected: metadata store.
  @protected
  SyncMetadataStore get metadataStore => _metadataStore;
}
