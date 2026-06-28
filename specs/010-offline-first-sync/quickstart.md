# Quickstart: Offline-First Sync Plugin

**Feature**: 010-offline-first-sync

## Generate an Offline-First Entity

```bash
# Create entity
zfa entity create -n EngagementEvent \
  --field id:String \
  --field eventType:String \
  --field userId:String?

# Generate full stack with sync
zfa make EngagementEvent \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --sync \
  --with=vpc \
  --state \
  --di \
  --test

# Register Hive adapters (including sync metadata)
zfa sync status EngagementEvent --build
```

## Use the Sync-Enabled Repository

```dart
// All operations are instant and offline-capable:

// 1. Create (writes to local immediately, returns instantly)
final event = EngagementEvent(
  id: 'evt_001',
  eventType: 'product_view',
  userId: 'user_123',
);
await getIt<EngagementEventRepository>().create(event);
// ↑ Returns in <5ms. No network call.

// 2. Read (reads from local only, instant)
final events = await getIt<EngagementEventRepository>().getList(
  ListQueryParams(),
);
// ↑ Returns in <5ms. No network call.

// 3. Delete (hard-deletes from local, tombstones for remote sync)
await getIt<EngagementEventRepository>().delete(
  DeleteParams(id: 'evt_001'),
);
// ↑ Returns instantly. Remote delete happens during sync.
```

## Trigger Sync Manually

```dart
// Using the generated Sync<Entity>UseCase:
final syncUseCase = GetIt.instance<SyncEngagementEventUseCase>();

// Trigger push sync (sends all pending records to remote)
await syncUseCase.execute(NoParams(), null);
```

## Trigger Sync on Connectivity Change

```dart
// In your app initialization or connectivity service:
Connectivity().onConnectivityChanged.listen((result) {
  if (result != ConnectivityResult.none) {
    // Network restored — trigger sync
    GetIt.instance<SyncEngagementEventUseCase>().execute(NoParams(), null);
  }
});
```

## Enable Bidirectional Sync

```bash
# Generate with bidirectional sync (push + pull)
zfa make EngagementEvent \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --sync \
  --bidirectional \
  --di
```

```dart
// Pull remote changes into local:
await getIt<EngagementEventRepository>().pullRemote();
```

## Add Sync to an Existing Entity

```bash
# Enable sync on an existing entity (append mode)
zfa sync enable ExistingEntity

# Or via make with append:
zfa make ExistingEntity --sync --append
```

This adds:
- Sync metadata store (separate Hive box)
- Sync strategy (push-only by default)
- `Sync<Entity>UseCase` for manual triggering
- Sync-aware repository methods (replaces existing CRUD methods)

The domain entity is NOT modified — no fields added. All sync tracking happens in the separate metadata store.

## Standalone Sync Command

```bash
# Enable sync on an entity
zfa sync enable EngagementEvent

# Check sync status / register metadata adapters
zfa sync status EngagementEvent

# View pending count (if supported)
zfa sync status EngagementEvent --verbose
```

## Verify Offline Behavior

```dart
// Test: all operations work with no network
test('sync-enabled repository works offline', () async {
  // Given: sync-enabled repository with local data
  await repository.create(testEvent);

  // When: device is offline (remote datasource throws)
  when(() => remoteDataSource.create(any()))
      .thenThrow(Exception('No network'));

  // Then: create still succeeds (local write)
  final result = await repository.create(anotherEvent);
  expect(result.id, isNotNull);

  // And: read works from local
  final list = await repository.getList(ListQueryParams());
  expect(list, hasLength(2));

  // And: sync will retry when network is available
  final pendingCount = await syncStrategy.getPendingCount();
  expect(pendingCount, equals(2));
});
```
