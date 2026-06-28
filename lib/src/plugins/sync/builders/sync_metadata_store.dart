import 'package:zuraffa/zuraffa.dart';

/// Hive-backed persistence layer for [SyncMetadata] records.
///
/// Each sync-enabled entity type gets its own [SyncMetadataStore] backed by
/// a `Box<SyncMetadata>`. This store tracks which local records need syncing,
/// their current [SyncStatus], retry counts, error messages, and tombstone
/// markers for deletions.
///
/// Keys are entity identifiers (typically `entity.id`). The store keeps the
/// domain entity pure — no sync infrastructure fields pollute it.
///
/// ## Example
///
/// ```dart
/// final box = await Hive.openBox<SyncMetadata>('product_sync_meta');
/// final store = SyncMetadataStore(box);
///
/// // Mark a record as pending after local create
/// await store.put('42', SyncMetadata(
///   status: SyncStatus.pending,
///   operation: SyncOperation.create,
/// ));
///
/// // Query pending records
/// final pendingKeys = await store.getKeysByStatus(SyncStatus.pending);
/// ```
class SyncMetadataStore {
  final Box<SyncMetadata> _box;

  SyncMetadataStore(this._box);

  /// Get sync metadata for [key], or `null` if the key is not tracked.
  Future<SyncMetadata?> get(String key) async {
    return _box.get(key);
  }

  /// Insert or replace sync metadata for [key].
  Future<void> put(String key, SyncMetadata metadata) async {
    await _box.put(key, metadata);
  }

  /// Remove sync metadata for [key].
  ///
  /// Called after a successful remote delete (tombstone processed)
  /// to clean up the tracking entry.
  Future<void> remove(String key) async {
    await _box.delete(key);
  }

  /// Get all keys whose metadata matches the given [status].
  ///
  /// Iterates all box keys and filters by the status field.
  Future<List<String>> getKeysByStatus(SyncStatus status) async {
    final keys = <String>[];
    for (final key in _box.keys) {
      final metadata = _box.get(key);
      if (metadata != null && metadata.status == status) {
        keys.add(key as String);
      }
    }
    return keys;
  }

  /// Count entries whose metadata matches the given [status].
  Future<int> countByStatus(SyncStatus status) async {
    var count = 0;
    for (final key in _box.keys) {
      final metadata = _box.get(key);
      if (metadata != null && metadata.status == status) {
        count++;
      }
    }
    return count;
  }

  /// Remove all sync metadata from the store.
  Future<void> clear() async {
    await _box.clear();
  }
}
