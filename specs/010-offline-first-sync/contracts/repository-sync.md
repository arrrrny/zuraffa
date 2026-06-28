# Contract: Sync-Enabled Repository

**Feature**: 010-offline-first-sync | **Layer**: Data (Generated)

## Location

Generated at: `lib/src/data/repositories/data_{entity_snake}_repository.dart`

## Purpose

The sync-enabled repository is the single entry point for all data operations when sync is enabled. It writes to local first (instant, offline-capable), reads from local only, and delegates sync orchestration to the injected `SyncStrategy`.

This mirrors how the cache-enabled repository delegates cache freshness to `CachePolicy`.

## Constructor Contract

```dart
class Data<Entity>Repository
    with Loggable, FailureHandler
    implements <Entity>Repository {
  Data<Entity>Repository(
    this._localDataSource,
    this._remoteDataSource,
    this._syncMetadataStore,
    this._syncStrategy,
  );

  final <Entity>LocalDataSource _localDataSource;
  final <Entity>DataSource _remoteDataSource;
  final SyncMetadataStore _syncMetadataStore;
  final SyncStrategy<<Entity>> _syncStrategy;
}
```

## Method Contracts

### Reads (Local Only)

```dart
@override
Future<Entity> get(QueryParams<Entity> params) async {
  cancelToken?.throwIfCancelled();
  return _localDataSource.get(params);
}

@override
Future<List<Entity>> getList(ListQueryParams<Entity> params) async {
  cancelToken?.throwIfCancelled();
  return _localDataSource.getList(params);
}
```

**Guarantee**: Never makes a network call. Returns instantly from local storage.

### Writes (Local First + Metadata)

```dart
@override
Future<Entity> create(Entity entity) async {
  cancelToken?.throwIfCancelled();
  final saved = await _localDataSource.create(entity);
  await _syncStrategy.markPending(_syncKey(saved), operation: SyncOperation.create);
  return saved;
}

@override
Future<Entity> update(UpdateParams<IdType, EntityPatch> params) async {
  cancelToken?.throwIfCancelled();
  final saved = await _localDataSource.update(params);
  await _syncStrategy.markPending(_syncKey(saved), operation: SyncOperation.update);
  return saved;
}

@override
Future<void> delete(DeleteParams<IdType> params) async {
  cancelToken?.throwIfCancelled();
  await _localDataSource.delete(params);
  await _syncStrategy.markDeleted(params.id.toString());
}
```

**Guarantee**: Writes return immediately after local persistence + metadata update. No network blocking.

### Sync Operations (Delegated to Strategy)

```dart
Future<void> syncPending({CancelToken? cancelToken}) {
  return _syncStrategy.syncPending(cancelToken: cancelToken);
}

Future<void> pullRemote({CancelToken? cancelToken}) {
  return _syncStrategy.pullRemote(cancelToken: cancelToken);
}
```

## Cache vs. Sync Comparison

| Aspect | Cache-Enabled Repository | Sync-Enabled Repository |
|--------|-------------------------|------------------------|
| Source of truth | Remote | Local |
| Write direction | Remote first → mirror to local | Local first → sync to remote |
| Read source | Local (if valid) or remote | Local only |
| Strategy injected | `CachePolicy` | `SyncStrategy<T>` |
| Dependencies | remote, local, cachePolicy | local, remote, metadataStore, syncStrategy |
| Offline writes | ❌ Fail (remote unreachable) | ✅ Succeed (local write) |
| Offline reads | ✅ From cache (if valid) | ✅ From local (always) |

## Mutual Exclusivity

`--cache` and `--sync` CANNOT be combined on the same entity. They represent opposite data flow strategies (remote-first vs. local-first). The generator will produce an error if both are specified.
