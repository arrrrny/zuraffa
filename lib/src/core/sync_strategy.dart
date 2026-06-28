import 'cancel_token.dart';
import 'sync_operation.dart';
import 'sync_status.dart';

/// Strategy interface for offline-first synchronization.
///
/// Defines HOW local changes are pushed to a remote data source and HOW
/// remote changes are pulled to local. Injected into sync-enabled
/// repositories alongside local/remote datasources.
///
/// This is analogous to [CachePolicy] for cached repositories — it is the
/// swappable strategy that controls non-CRUD behavior.
///
/// ## Example implementations
///
/// - [PushOnlySyncStrategy]: pushes local changes to remote (default)
/// - [BidirectionalSyncStrategy]: pushes local + pulls remote
///
/// ## Usage in generated repositories
///
/// ```dart
/// class DataProductRepository implements ProductRepository {
///   DataProductRepository(
///     this._localDataSource,
///     this._remoteDataSource,
///     this._syncMetadataStore,
///     this._syncStrategy,   // ← SyncStrategy<Product>
///   );
///
///   @override
///   Future<Product> create(Product product) async {
///     final saved = await _localDataSource.create(product);
///     await _syncStrategy.markPending(saved.id);
///     return saved;
///   }
///
///   Future<void> syncPending({CancelToken? cancelToken}) {
///     return _syncStrategy.syncPending(cancelToken: cancelToken);
///   }
/// }
/// ```
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
