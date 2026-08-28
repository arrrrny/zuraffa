import 'package:test/test.dart';
import 'package:zuraffa/src/core/sync_config.dart';
import 'package:zuraffa/src/core/sync_metadata.dart';
import 'package:zuraffa/src/core/sync_operation.dart';
import 'package:zuraffa/src/core/sync_status.dart';
import 'package:zuraffa/src/plugins/sync/builders/push_only_sync_strategy.dart';
import 'package:zuraffa/src/plugins/sync/builders/sync_metadata_store.dart';

/// Test entity for sync strategy tests.
class TestEntity {
  final String id;
  final String name;
  const TestEntity({required this.id, required this.name});
}

/// Native fake [SyncMetadataStore] backed by the test's in-memory [metaMap]
/// (instead of a mocktail mock wired with `when(...).thenAnswer`).
class FakeSyncMetadataStore implements SyncMetadataStore {
  final Map<String, SyncMetadata> metaMap;
  FakeSyncMetadataStore(this.metaMap);

  @override
  Future<SyncMetadata?> get(String key) async => metaMap[key];

  @override
  Future<void> put(String key, SyncMetadata metadata) async {
    metaMap[key] = metadata;
  }

  @override
  Future<void> remove(String key) async => metaMap.remove(key);

  @override
  Future<List<String>> getKeysByStatus(SyncStatus status) async =>
      metaMap.entries
          .where((e) => e.value.status == status)
          .map((e) => e.key)
          .toList();

  @override
  Future<int> countByStatus(SyncStatus status) async =>
      metaMap.values.where((m) => m.status == status).length;

  @override
  Future<void> clear() async => metaMap.clear();
}

void main() {
  late FakeSyncMetadataStore metadataStore;
  late PushOnlySyncStrategy<TestEntity> strategy;

  // In-memory storage for the test
  final localStore = <String, TestEntity>{};
  final createdRemote = <TestEntity>[];
  final updatedRemote = <TestEntity>[];
  final deletedRemote = <String>[];
  final metaMap = <String, SyncMetadata>{};

  setUp(() {
    metadataStore = FakeSyncMetadataStore(metaMap);
    localStore.clear();
    createdRemote.clear();
    updatedRemote.clear();
    deletedRemote.clear();
    metaMap.clear();

    strategy = PushOnlySyncStrategy<TestEntity>(
      fetchLocal: (keys) async {
        return keys.map((k) => localStore[k]).whereType<TestEntity>().toList();
      },
      createRemote: (entity) async {
        createdRemote.add(entity);
        return entity;
      },
      updateRemote: (entity) async {
        updatedRemote.add(entity);
        return entity;
      },
      deleteRemote: (key) async {
        deletedRemote.add(key);
      },
      keyResolver: (entity) => entity.id,
      metadataStore: metadataStore,
      config: const SyncConfig(batchSize: 2, maxRetries: 3),
    );
  });

  group('PushOnlySyncStrategy', () {
    test('markPending creates pending metadata', () async {
      await strategy.markPending('test_1', operation: SyncOperation.create);

      final status = await strategy.getSyncStatus('test_1');
      expect(status, equals(SyncStatus.pending));
    });

    test('markDeleted creates tombstone metadata', () async {
      await strategy.markDeleted('test_1');

      final metadata = await metadataStore.get('test_1');
      expect(metadata, isNotNull);
      expect(metadata!.isTombstone, isTrue);
      expect(metadata.operation, equals(SyncOperation.delete));
    });

    test('syncPending pushes created entities to remote', () async {
      final entity = const TestEntity(id: 'p1', name: 'Product 1');
      localStore['p1'] = entity;
      await strategy.markPending('p1', operation: SyncOperation.create);

      await strategy.syncPending();

      expect(createdRemote, hasLength(1));
      expect(createdRemote.first.id, equals('p1'));

      final status = await strategy.getSyncStatus('p1');
      expect(status, equals(SyncStatus.synced));
    });

    test('syncPending pushes updated entities to remote', () async {
      final entity = const TestEntity(id: 'p1', name: 'Updated');
      localStore['p1'] = entity;
      await strategy.markPending('p1', operation: SyncOperation.update);

      await strategy.syncPending();

      expect(updatedRemote, hasLength(1));
      expect(updatedRemote.first.id, equals('p1'));
    });

    test('syncPending processes tombstones (remote delete)', () async {
      await strategy.markDeleted('p1');

      await strategy.syncPending();

      expect(deletedRemote, contains('p1'));
      final metadata = await metadataStore.get('p1');
      expect(metadata, isNull);
    });

    test('failed sync retries and eventually marks as failed', () async {
      var callCount = 0;
      final failingStrategy = PushOnlySyncStrategy<TestEntity>(
        fetchLocal: (keys) async {
          return keys
              .map((k) => localStore[k])
              .whereType<TestEntity>()
              .toList();
        },
        createRemote: (entity) async {
          callCount++;
          throw Exception('Network error');
        },
        updateRemote: (entity) async => entity,
        deleteRemote: (key) async {},
        keyResolver: (entity) => entity.id,
        metadataStore: metadataStore,
        config: const SyncConfig(batchSize: 10, maxRetries: 2),
      );

      localStore['p1'] = const TestEntity(id: 'p1', name: 'Product 1');
      await failingStrategy.markPending('p1', operation: SyncOperation.create);

      // First sync: fails, retryCount=1, status=pending
      await failingStrategy.syncPending();
      var metadata = await metadataStore.get('p1');
      expect(metadata!.retryCount, equals(1));
      expect(metadata.status, equals(SyncStatus.pending));

      // Second sync: fails, retryCount=2 >= maxRetries(2), status=failed
      await failingStrategy.syncPending();
      metadata = await metadataStore.get('p1');
      expect(metadata!.retryCount, equals(2));
      expect(metadata.status, equals(SyncStatus.failed));
      expect(metadata.lastError, contains('Network error'));

      // createRemote was called exactly twice (once per sync attempt)
      expect(callCount, equals(2));
    });

    test('getPendingCount returns pending + failed count', () async {
      await strategy.markPending('p1');
      await strategy.markPending('p2');
      await strategy.markPending('p3');

      final count = await strategy.getPendingCount();
      expect(count, equals(3));
    });

    test('syncPending is no-op when nothing pending', () async {
      await strategy.syncPending();

      expect(createdRemote, isEmpty);
      expect(updatedRemote, isEmpty);
      expect(deletedRemote, isEmpty);
    });

    test('pullRemote throws UnimplementedError', () async {
      expect(() => strategy.pullRemote(), throwsA(isA<UnimplementedError>()));
    });

    test('batch processing handles multiple entities', () async {
      for (var i = 0; i < 5; i++) {
        final id = 'batch_$i';
        localStore[id] = TestEntity(id: id, name: 'Product $i');
        await strategy.markPending(id, operation: SyncOperation.create);
      }

      await strategy.syncPending();

      expect(createdRemote, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final status = await strategy.getSyncStatus('batch_$i');
        expect(status, equals(SyncStatus.synced));
      }
    });
  });
}
