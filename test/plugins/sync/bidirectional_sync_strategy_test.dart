import 'package:test/test.dart';
import 'package:zuraffa/src/core/cancel_token.dart';
import 'package:zuraffa/src/core/sync_config.dart';
import 'package:zuraffa/src/core/sync_metadata.dart';
import 'package:zuraffa/src/core/sync_operation.dart';
import 'package:zuraffa/src/core/sync_status.dart';
import 'package:zuraffa/src/plugins/sync/builders/bidirectional_sync_strategy.dart';
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
  Future<List<String>> getKeysByStatus(SyncStatus status) async => metaMap
      .entries
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

  // In-memory storage for the test
  final localStore = <String, TestEntity>{};
  final savedLocally = <String, TestEntity>{};
  final metaMap = <String, SyncMetadata>{};

  // Captures conflict-resolver invocations: (local?.id, remote.id)
  final conflictCalls = <(String?, String)>[];

  /// Build a [BidirectionalSyncStrategy] wired to the in-memory test stores.
  ///
  /// [remoteList] is the data returned by the remote data source.
  /// [conflictResolver] customizes conflict resolution (defaults to remote
  /// wins, mirroring the production default).
  BidirectionalSyncStrategy<TestEntity> buildStrategy({
    List<TestEntity>? remoteList,
    TestEntity Function(TestEntity? local, TestEntity remote)? conflictResolver,
  }) {
    return BidirectionalSyncStrategy<TestEntity>(
      fetchLocal: (keys) async {
        return keys.map((k) => localStore[k]).whereType<TestEntity>().toList();
      },
      createRemote: (entity) async => entity,
      updateRemote: (entity) async => entity,
      deleteRemote: (key) async {},
      keyResolver: (entity) => entity.id,
      metadataStore: metadataStore,
      fetchRemoteList: () async => remoteList ?? const [],
      saveLocal: (entity) async {
        savedLocally[entity.id] = entity;
      },
      conflictResolver:
          conflictResolver ??
          ((local, remote) {
            conflictCalls.add((local?.id, remote.id));
            return remote;
          }),
    );
  }

  setUp(() {
    metadataStore = FakeSyncMetadataStore(metaMap);
    localStore.clear();
    savedLocally.clear();
    metaMap.clear();
    conflictCalls.clear();
  });

  group('BidirectionalSyncStrategy.pullRemote', () {
    test('fetches remote records and saves untracked ones as synced', () async {
      final strategy = buildStrategy(
        remoteList: const [TestEntity(id: 'r1', name: 'Remote 1')],
      );

      await strategy.pullRemote();

      expect(savedLocally['r1'], isNotNull);
      expect(savedLocally['r1']!.name, equals('Remote 1'));

      final metadata = await metadataStore.get('r1');
      expect(metadata, isNotNull);
      expect(metadata!.status, equals(SyncStatus.synced));
      expect(metadata.operation, equals(SyncOperation.update));
    });

    test('accepts remote changes for already-synced local records', () async {
      localStore['s1'] = const TestEntity(id: 's1', name: 'Stale Local');
      metaMap['s1'] = const SyncMetadata(
        status: SyncStatus.synced,
        operation: SyncOperation.update,
      );

      final strategy = buildStrategy(
        remoteList: const [TestEntity(id: 's1', name: 'Fresh Remote')],
      );
      await strategy.pullRemote();

      // Remote version should overwrite the stale local copy.
      expect(savedLocally['s1']!.name, equals('Fresh Remote'));
      final metadata = await metadataStore.get('s1');
      expect(metadata!.status, equals(SyncStatus.synced));
    });

    test('resolves conflict with default resolver (remote wins)', () async {
      localStore['c1'] = const TestEntity(id: 'c1', name: 'Local Pending');
      metaMap['c1'] = const SyncMetadata(
        status: SyncStatus.pending,
        operation: SyncOperation.update,
      );

      final strategy = buildStrategy(
        remoteList: const [TestEntity(id: 'c1', name: 'Remote')],
      );
      await strategy.pullRemote();

      // Default resolver returns remote → local pending change is discarded.
      expect(savedLocally['c1']!.name, equals('Remote'));
      final metadata = await metadataStore.get('c1');
      expect(metadata!.status, equals(SyncStatus.synced));
    });

    test(
      'uses custom resolver returning local (local wins, keeps pending)',
      () async {
        localStore['c2'] = const TestEntity(id: 'c2', name: 'Local Pending');
        metaMap['c2'] = const SyncMetadata(
          status: SyncStatus.pending,
          operation: SyncOperation.update,
        );

        final strategy = buildStrategy(
          remoteList: const [TestEntity(id: 'c2', name: 'Remote')],
          conflictResolver: (local, remote) => local!,
        );
        await strategy.pullRemote();

        // Local version is kept and the record remains pending for next push.
        expect(savedLocally['c2']!.name, equals('Local Pending'));
        final metadata = await metadataStore.get('c2');
        expect(metadata!.status, equals(SyncStatus.pending));
        expect(metadata.operation, equals(SyncOperation.update));
      },
    );

    test('invokes conflict resolver with local and remote versions', () async {
      localStore['c3'] = const TestEntity(id: 'c3', name: 'Local');
      metaMap['c3'] = const SyncMetadata(
        status: SyncStatus.failed,
        operation: SyncOperation.update,
      );

      final strategy = buildStrategy(
        remoteList: const [TestEntity(id: 'c3', name: 'Remote')],
      );
      await strategy.pullRemote();

      expect(conflictCalls, hasLength(1));
      expect(conflictCalls.first.$1, equals('c3')); // local id
      expect(conflictCalls.first.$2, equals('c3')); // remote id
    });

    test('is a no-op when there are no remote records', () async {
      final strategy = buildStrategy(remoteList: const []);
      await strategy.pullRemote();

      expect(savedLocally, isEmpty);
      expect(metaMap, isEmpty);
      expect(conflictCalls, isEmpty);
    });

    test('processes multiple records across mixed states', () async {
      // r1: untracked → accept remote + synced
      // s1: synced locally → accept remote + synced
      // c1: pending locally → conflict, remote wins + synced
      localStore['s1'] = const TestEntity(id: 's1', name: 'Stale Local');
      localStore['c1'] = const TestEntity(id: 'c1', name: 'Local Pending');
      metaMap['s1'] = const SyncMetadata(
        status: SyncStatus.synced,
        operation: SyncOperation.update,
      );
      metaMap['c1'] = const SyncMetadata(
        status: SyncStatus.pending,
        operation: SyncOperation.update,
      );

      final strategy = buildStrategy(
        remoteList: const [
          TestEntity(id: 'r1', name: 'Remote R1'),
          TestEntity(id: 's1', name: 'Fresh Remote'),
          TestEntity(id: 'c1', name: 'Remote C1'),
        ],
      );
      await strategy.pullRemote();

      expect(savedLocally, hasLength(3));
      expect(savedLocally['r1']!.name, equals('Remote R1'));
      expect(savedLocally['s1']!.name, equals('Fresh Remote'));
      expect(savedLocally['c1']!.name, equals('Remote C1'));

      expect(
        (await metadataStore.get('r1'))!.status,
        equals(SyncStatus.synced),
      );
      expect(
        (await metadataStore.get('s1'))!.status,
        equals(SyncStatus.synced),
      );
      expect(
        (await metadataStore.get('c1'))!.status,
        equals(SyncStatus.synced),
      );
    });

    test(
      'does not pull remote when the cancel token is already cancelled',
      () async {
        final token = CancelToken()..cancel('test cancel');
        final strategy = buildStrategy(
          remoteList: const [TestEntity(id: 'r1', name: 'Remote 1')],
        );

        await expectLater(
          () => strategy.pullRemote(cancelToken: token),
          throwsA(isA<CancelledException>()),
        );

        // Nothing should have been saved or recorded when cancelled up front.
        expect(savedLocally, isEmpty);
        expect(metaMap, isEmpty);
        expect(conflictCalls, isEmpty);
      },
    );

    test('can be built with a non-default sync config', () async {
      // Sanity check that the bidirectional strategy honors the parent
      // constructor contract (config is forwarded to the push pipeline).
      final configured = buildStrategy(
        remoteList: const [],
        // Provide a custom resolver just to exercise the optional param.
        conflictResolver: (local, remote) => remote,
      );
      expect(configured, isA<BidirectionalSyncStrategy<TestEntity>>());

      final withConfig = BidirectionalSyncStrategy<TestEntity>(
        fetchLocal: (keys) async =>
            keys.map((k) => localStore[k]).whereType<TestEntity>().toList(),
        createRemote: (e) async => e,
        updateRemote: (e) async => e,
        deleteRemote: (key) async {},
        keyResolver: (e) => e.id,
        metadataStore: metadataStore,
        fetchRemoteList: () async => const [],
        saveLocal: (e) async {},
        config: const SyncConfig(batchSize: 4, maxRetries: 1),
      );
      expect(withConfig, isA<BidirectionalSyncStrategy<TestEntity>>());
    });
  });
}
