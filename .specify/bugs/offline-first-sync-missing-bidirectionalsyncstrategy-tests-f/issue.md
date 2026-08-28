# Bug Issue: Offline-First Sync: Missing BidirectionalSyncStrategy tests (FR-014)

- **Slug**: offline-first-sync-missing-bidirectionalsyncstrategy-tests-f
- **Fetched**: 2026-08-27T14:26:41.527999+00:00
- **Issue**: 498
- **URL**: https://github.com/arrrrny/zuraffa/issues/498
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

# Bug Assessment: Missing BidirectionalSyncStrategy Tests + Incomplete US5 Coverage (Feature 010)

**Feature**: 010-offline-first-sync
**Slug**: `010-offline-first-sync-missing-bidirectional-tests`
**Severity**: High
**Status**: Open
**Detected**: 2026-08-26 (during TDD verification)
**Assessor**: TDD verification (speckit-tdd-verify equivalent)

---

## Summary

The `BidirectionalSyncStrategy` class is fully implemented in `lib/src/plugins/sync/builders/bidirectional_sync_strategy.dart` but has **zero test coverage**. This violates FR-014's explicit requirement for "bidirectional pull sync" tests and leaves US5 (Priority P2) completely unverified.

---

## Root Cause Analysis

### Implementation Exists But Untested

**File**: `lib/src/plugins/sync/builders/bidirectional_sync_strategy.dart` (134 lines)
- Extends `PushOnlySyncStrategy<T>`
- Implements `pullRemote()` with full conflict resolution logic
- Uses configurable `ConflictResolver<T>` callback (default: remote wins)
- Handles local records not present in remote pull

**Missing**: `test/plugins/sync/bidirectional_sync_strategy_test.dart` (Task T050)

### FR-014 Violation

> "The sync plugin MUST generate tests for the sync-enabled repository and SyncStrategy, covering: push sync success, push sync failure with retry, read from local, **and bidirectional pull sync**."

The "bidirectional pull sync" coverage is **0%**.

### US5 Acceptance Criteria Unverified

| Acceptance Scenario | Status |
|---------------------|--------|
| A5.1: Remote has newer data → pull sync fetches and updates local | ❌ No test |
| A5.2: Both local+remote have changes → push first, then pull, conflicts resolved (default: remote wins) | ❌ No test |

### Specific Untested Behaviors (from verification)

| Behavior ID | Description | Risk |
|-------------|-------------|------|
| U6.3 | `pullRemote()` fetches remote list, saves to local, marks synced | High |
| U6.4 | Conflict resolution: default remote-wins | High |
| U6.5 | Conflict resolution: custom resolver can return local | Medium |
| U6.6 | Local records not in remote (and synced) are deleted | Medium |

---

## Reproduction Steps

```bash
# 1. Try to run bidirectional strategy tests
dart test test/plugins/sync/bidirectional_sync_strategy_test.dart

# Result: "No such file or directory"

# 2. Verify implementation exists
ls -la lib/src/plugins/sync/builders/bidirectional_sync_strategy.dart

# Result: File exists (134 lines, fully implemented)

# 3. Check if any tests reference bidirectional
grep -r "BidirectionalSyncStrategy" test/

# Result: No matches
```

---

## Code Under Test (Key Methods)

### `pullRemote()` - Primary Untested Method
```dart
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
      await metadataStore.put(key, SyncMetadata(
        status: SyncStatus.synced,
        operation: SyncOperation.update,
      ));
    } else {
      // Pending or failed locally → conflict
      await _resolveConflict(key, remote, metadata, cancelToken);
    }
  }
  logger.info('Pull complete');
}
```

### `_resolveConflict()` - Core Conflict Logic
```dart
Future<void> _resolveConflict(
  String key,
  T remote,
  SyncMetadata metadata,
  CancelToken? cancelToken,
) async {
  final localEntities = await fetchLocal([key]);
  final local = localEntities.isEmpty ? null : localEntities.first;
  cancelToken?.throwIfCancelled();

  final resolved = _conflictResolver(local, remote);
  await _saveLocal(resolved);

  if (identical(resolved, remote) || resolved == remote) {
    // Remote wins → mark synced
    await metadataStore.put(key, SyncMetadata(
      status: SyncStatus.synced,
      operation: SyncOperation.update,
    ));
  } else {
    // Local wins → keep pending
    logger.fine('Conflict resolved for $key: local wins, keeping pending');
  }
}
```

### Default ConflictResolver
```dart
_conflictResolver = conflictResolver ?? ((local, remote) => remote);
```

---

## Suggested Fix

### Create `test/plugins/sync/bidirectional_sync_strategy_test.dart`

Following the pattern of `push_only_sync_strategy_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/src/core/sync_config.dart';
import 'package:zuraffa/src/core/sync_metadata.dart';
import 'package:zuraffa/src/core/sync_operation.dart'
import 'package:zuraffa/src/core/sync_status.dart';
import 'package:zuraffa/src/plugins/sync/builders/bidirectional_sync_strategy.dart';
import 'package:zuraffa/src/plugins/sync/builders/sync_metadata_store.dart';

class TestEntity {
  final String id;
  final String name;
  final DateTime updatedAt;
  const TestEntity({required this.id, required this.name, required this.updatedAt});
}

class MockSyncMetadataStore extends Mock implements SyncMetadataStore {}

void main() {
  late MockSyncMetadataStore metadataStore;
  late BidirectionalSyncStrategy<TestEntity> strategy;
  final localStore = <String, TestEntity>{};
  final remoteStore = <TestEntity>[];
  final savedLocal = <TestEntity>[];
  final metaMap = <String, SyncMetadata>{};

  setUpAll(() {
    registerFallbackValue(SyncStatus.pending);
    registerFallbackValue(SyncStatus.synced);
    registerFallbackValue(SyncStatus.syncing);
    registerFallbackValue(SyncStatus.failed);
    registerFallbackValue(const SyncMetadata(
      status: SyncStatus.pending,
      operation: SyncOperation.create,
    ));
    registerFallbackValue(const SyncMetadata(
      status: SyncStatus.synced,
      operation: SyncOperation.update,
    ));
  });

  setUp(() {
    metadataStore = MockSyncMetadataStore();
    localStore.clear();
    remoteStore.clear();
    savedLocal.clear();
    metaMap.clear();

    when(() => metadataStore.get(any())).thenAnswer((inv) async {
      return metaMap[inv.positionalArguments[0] as String];
    });
    when(() => metadataStore.put(any(), any())).thenAnswer((inv) async {
      metaMap[inv.positionalArguments[0] as String] =
          inv.positionalArguments[1] as SyncMetadata;
    });
    when(() => metadataStore.remove(any())).thenAnswer((inv) async {
      metaMap.remove(inv.positionalArguments[0] as String);
    });
    when(() => metadataStore.getKeysByStatus(any())).thenAnswer((inv) async {
      final status = inv.positionalArguments[0] as SyncStatus;
      return metaMap.entries
          .where((e) => e.value.status == status)
          .map((e) => e.key)
          .toList();
    });
    when(() => metadataStore.countByStatus(any())).thenAnswer((inv) async {
      final status = inv.positionalArguments[0] as SyncStatus;
      return metaMap.values.where((m) => m.status == status).length;
    });

    strategy = BidirectionalSyncStrategy<TestEntity>(
      fetchLocal: (keys) async {
        return keys.map((k) => localStore[k]).whereType<TestEntity>().toList();
      },
      createRemote: (entity) async {
        remoteStore.add(entity);
        return entity;
      },
      updateRemote: (entity) async => entity,
      deleteRemote: (key) async {},
      keyResolver: (entity) => entity.id,
      metadataStore: metadataStore,
      fetchRemoteList: () async => List.from(remoteStore),
      saveLocal: (entity) async {
        savedLocal.add(entity);
        localStore[entity.id] = entity;
      },
      config: const SyncConfig(batchSize: 2, maxRetries: 3),
    );
  });

  group('BidirectionalSyncStrategy', () {
    test('pullRemote fetches remote records and saves to local', () async {
      remoteStore.addAll([
        const TestEntity(id: 'r1', name: 'Remote 1', updatedAt: DateTime.now()),
        const TestEntity(id: 'r2', name: 'Remote 2', updatedAt: DateTime.now()),
      ]);

      await strategy.pullRemote();

      expect(savedLocal, hasLength(2));
      expect(localStore['r1']!.name, equals('Remote 1'));
      expect(localStore['r2']!.name, equals('Remote 2'));

      // Both should be marked synced
      final meta1 = await metadataStore.get('r1');
      final meta2 = await metadataStore.get('r2');
      expect(meta1!.status, equals(SyncStatus.synced));
      expect(meta2!.status, equals(SyncStatus.synced));
    });

    test('pullRemote: conflict with pending local - remote wins by default', () async {
      // Local has pending change
      localStore['c1'] = const TestEntity(
        id: 'c1', name: 'Local Pending', updatedAt: DateTime.now());
      await strategy.markPending('c1', operation: SyncOperation.update);

      // Remote has different data
      remoteStore.add(const TestEntity(
        id: 'c1', name: 'Remote Version', updatedAt: DateTime.now()));

      await strategy.pullRemote();

      // Remote should win - local overwritten
      expect(localStore['c1']!.name, equals('Remote Version'));
      // Should be marked synced (local pending discarded)
      final meta = await metadataStore.get('c1');
      expect(meta!.status, equals(SyncStatus.synced));
    });

    test('pullRemote: conflict with custom resolver - local wins', () async {
      // Local has pending change
      final localEntity = const TestEntity(
        id: 'c2', name: 'Local Wins', updatedAt: DateTime.now());
      localStore['c2'] = localEntity;
      await strategy.markPending('c2', operation: SyncOperation.update);

      // Remote has different data
      remoteStore.add(const TestEntity(
        id: 'c2', name: 'Remote Version', updatedAt: DateTime.now()));

      // Create strategy with custom resolver (local wins if updatedAt newer)
      final customStrategy = BidirectionalSyncStrategy<TestEntity>(
        fetchLocal: (keys) async => keys.map((k) => localStore[k]).whereType<TestEntity>().toList(),
        createRemote: (e) async => e,
        updateRemote: (e) async => e,
        deleteRemote: (k) async {},
        keyResolver: (e) => e.id,
        metadataStore: metadataStore,
        fetchRemoteList: () async => List.from(remoteStore),
        saveLocal: (e) async {
          savedLocal.add(e);
          localStore[e.id] = e;
        },
        conflictResolver: (local, remote) {
          if (local == null) return remote;
          // Local wins if it has newer timestamp
          return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
        },
        config: const SyncConfig(batchSize: 2, maxRetries: 3),
      );

      await customStrategy.pullRemote();

      // Local should win (same timestamp in test, but resolver returns local)
      expect(localStore['c2']!.name, equals('Local Wins'));
      // Should remain pending
      final meta = await metadataStore.get('c2');
      expect(meta!.status, equals(SyncStatus.pending));
    });

    test('pullRemote: local synced records not in remote are deleted', () async {
      // Local has synced record
      localStore['del1'] = const TestEntity(
        id: 'del1', name: 'To Delete', updatedAt: DateTime.now());
      await metadataStore.put('del1', const SyncMetadata(
        status: SyncStatus.synced,
        operation: SyncOperation.update,
      ));

      // Remote does NOT have this record
      remoteStore.clear();

      await strategy.pullRemote();

      // Local record should be deleted
      expect(localStore.containsKey('del1'), isFalse);
      // Metadata should be removed
      final meta = await metadataStore.get('del1');
      expect(meta, isNull);
    });

    test('pullRemote: local pending records not in remote are KEPT (not deleted)', () async {
      // Local has pending record (not synced)
      localStore['keep1'] = const TestEntity(
        id: 'keep1', name: 'Keep Me', updatedAt: DateTime.now());
      await strategy.markPending('keep1', operation: SyncOperation.create);

      // Remote does NOT have this record
      remoteStore.clear();

      await strategy.pullRemote();

      // Local record should STILL exist (pending changes not discarded)
      expect(localStore.containsKey('keep1'), isTrue);
      // Metadata should remain pending
      final meta = await metadataStore.get('keep1');
      expect(meta!.status, equals(SyncStatus.pending));
    });

    test('pullRemote respects CancelToken', () async {
      final cancelToken = CancelToken();
      remoteStore.addAll(List.generate(100, (i) => TestEntity(
        id: 'r$i', name: 'Remote $i', updatedAt: DateTime.now())));

      // Cancel immediately
      cancelToken.cancel();

      expect(() => strategy.pullRemote(cancelToken: cancelToken),
          throwsA(isA<CancelledError>()));
    });
  });
}
```

---

## Acceptance Criteria for Fix

- [ ] `test/plugins/sync/bidirectional_sync_strategy_test.dart` created
- [ ] All 6 test cases above pass
- [ ] Test covers: pullRemote basic, conflict remote-wins, conflict custom resolver, local-only deletion, pending preservation, CancelToken
- [ ] FR-014 "bidirectional pull sync" coverage achieved
- [ ] US5 acceptance criteria A5.1, A5.2 verifiable

---

## Related Files

- `lib/src/plugins/sync/builders/bidirectional_sync_strategy.dart` - implementation to test
- `lib/src/plugins/sync/builders/push_only_sync_strategy.dart` - parent class
- `test/plugins/sync/push_only_sync_strategy_test.dart` - exemplar pattern
- `lib/src/plugins/sync/sync_plugin.dart` - configSchema includes bidirectional

---

## Timeline

**Detected**: 2026-08-26 during TDD verification
**Target Fix**: Before feature 010 considered complete
**Blocking**: Feature 010 US5 completion, FR-014 compliance

## Comments

None.
