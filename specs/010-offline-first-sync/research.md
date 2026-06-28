# Research: Offline-First Sync Plugin

**Date**: 2026-06-28 | **Feature**: 010-offline-first-sync

## Research Tasks & Findings

### R1: Cache Plugin Architecture Analysis

**Task**: Understand the existing CachePlugin structure to mirror it for SyncPlugin.

**Decision**: Mirror the cache plugin's 6-component structure exactly:
1. `SyncPlugin` (plugin class) — registered in PluginLoader
2. `SyncCommand` (CLI command) — `zfa sync <Entity>`
3. `SyncBuilder` (file generator) — generates sync support files
4. `CreateSyncCapability` — enables sync via `zfa make --sync` or `zfa sync enable <Entity>`
5. `CreateSyncStatusCapability` — initializes sync metadata store
6. Config schema with `sync-direction`, `sync-batch-size`, `sync-max-retries`

**Rationale**: The cache plugin is the canonical reference for "data coordination" plugins in Zuraffa. Following its structure ensures consistency, testability, and developer familiarity. The `runAfter` property will be set to `['datasource', 'repository']` to ensure sync runs after the datasources and repository interface are generated.

**Alternatives considered**:
- Extending the cache plugin with sync mode — rejected because cache and sync are fundamentally different strategies (remote-first vs. local-first), and mixing them would violate SRP.
- Creating sync as a flag-only feature without a standalone plugin — rejected per user directive (must be callable independently like cache).

---

### R2: SyncStrategy Interface Design

**Task**: Design the `SyncStrategy` domain interface (analogous to `CachePolicy`).

**Decision**: `SyncStrategy` is an abstract class in `lib/src/core/sync_strategy.dart`, exported via `zuraffa.dart`. It defines the contract for how local changes are pushed to remote and how remote changes are pulled to local.

```dart
abstract class SyncStrategy<T> {
  /// Push all pending local changes to the remote data source.
  /// Processes records with SyncStatus.pending or SyncStatus.failed.
  Future<void> syncPending({CancelToken? cancelToken});

  /// Pull remote data and merge into local storage (bidirectional only).
  Future<void> pullRemote({CancelToken? cancelToken});

  /// Get count of records pending sync.
  Future<int> getPendingCount();

  /// Get sync status for a specific record.
  Future<SyncStatus> getSyncStatus(String key);

  /// Mark a record as pending sync (called by repository on write).
  Future<void> markPending(String key);

  /// Mark a record as tombstoned (deleted locally, pending remote delete).
  Future<void> markDeleted(String key);
}
```

**Rationale**: Mirrors `CachePolicy`'s method style (`isValid`, `markFresh`, `invalidate` → `syncPending`, `markPending`, `markDeleted`). Generic type `<T>` ensures type safety per entity. CancelToken support for cancellation. The strategy is injected into the repository alongside the datasources and metadata store.

**Alternatives considered**:
- Non-generic interface (using `dynamic`) — rejected for type safety.
- Separate `SyncEngine` component — rejected per Q3 clarification (embedded + Strategy pattern).

---

### R3: SyncMetadataStore Design

**Task**: Design the separate metadata store for tracking sync status without polluting the domain entity.

**Decision**: A Hive-based store that maps entity identifier → `SyncMetadata`. The key strategy:
- If entity has an `id` field (most entities), use `entity.id` as the key
- If entity has no `id` field (singleton configs), use `entity.hashCode` as the key

```dart
class SyncMetadata {
  final SyncStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime? deletedAt;  // tombstone timestamp
}
```

The store uses a dedicated Hive box (e.g., `sync_metadata_<entity_snake>`) storing `SyncMetadata` values keyed by String entity identifiers. This is a data-layer concern — the domain `SyncStrategy` interface doesn't know about Hive.

**Rationale**: Keeping sync metadata in a separate Hive box means:
1. Domain entity stays pure (no infrastructure fields)
2. Sync metadata can be cleared without affecting entity data
3. Querying pending records is efficient (filter the metadata box by status)
4. The metadata box is small (just status + timestamps, not full entities)

**Alternatives considered**:
- Adding `syncStatus` field to the entity — rejected per Q2 clarification (domain purity).
- Using SharedPreferences for metadata — rejected (no efficient batch querying, no custom objects).
- In-memory tracking — rejected (lost on app restart, breaks offline-first promise).

---

### R4: Sync-Enabled Repository Method Generation

**Task**: Design the generated repository methods for sync mode (analogous to `_buildCacheAware*Body` methods).

**Decision**: Create `implementation_generator_synced.dart` as a part of `implementation_generator.dart`, mirroring `implementation_generator_cached.dart`. The sync-enabled repository constructor takes 4 dependencies:

```dart
DataProductRepository(
  this._localDataSource,    // Hive-backed local data source
  this._remoteDataSource,   // Remote API data source
  this._syncMetadataStore,  // Sync status tracking (separate Hive box)
  this._syncStrategy,       // Push/pull orchestration strategy
);
```

Method body patterns:

| Method | Sync-Enabled Behavior |
|--------|-----------------------|
| `get(params)` | Read from `_localDataSource` only. No network call. |
| `getList(params)` | Read from `_localDataSource` only. No network call. |
| `create(entity)` | Write to `_localDataSource.create(entity)` + `_syncStrategy.markPending(key)`. Return immediately. |
| `update(params)` | Write to `_localDataSource.update(params)` + `_syncStrategy.markPending(key)`. Return immediately. |
| `delete(params)` | Hard-delete from `_localDataSource.delete(params)` + `_syncStrategy.markDeleted(key)`. Return immediately. |
| `syncPending(cancelToken)` | Delegate to `_syncStrategy.syncPending(cancelToken)`. |
| `pullRemote(cancelToken)` | Delegate to `_syncStrategy.pullRemote(cancelToken)`. (Bidirectional only) |

**Rationale**: The repository is the single entry point for all data operations. Embedding sync logic in the repository (like cache logic) means the developer never touches generated code. The strategy pattern allows swapping push-only vs. bidirectional without regenerating the repository.

**Alternatives considered**:
- Separate SyncEngine component — rejected per Q3 clarification (embedded + Strategy pattern).
- Making the repository orchestrate sync internally (no strategy) — rejected for flexibility.

---

### R5: Entity Key Resolution Strategy

**Task**: Determine how to resolve the entity key for sync metadata tracking when entities may or may not have an `id` field.

**Decision**: Use a resolver function approach:
1. Check if entity has a field named `id` (analyzed at generation time via `EntityAnalyzer`)
2. If yes: generated code uses `entity.id` as the metadata key
3. If no: generated code uses `entity.hashCode.toString()` as the metadata key

The generated repository will have the key resolution built in:

```dart
// Generated for entity WITH id field:
String _syncKey(Product entity) => entity.id;

// Generated for entity WITHOUT id field:
String _syncKey(AppConfig entity) => entity.hashCode.toString();
```

**Rationale**: All Zorphy entities generate a `hashCode` via `Object.hash(...)`, so there's always a usable key. Using `id` when available is more stable (hashCode can change if fields change). The key resolution is determined at generation time, not runtime, for performance.

**Alternatives considered**:
- Requiring all sync-enabled entities to have an `id` field — rejected (too restrictive, singleton entities like AppConfig have no id).
- Using entity JSON serialization as key — rejected (performance overhead, unnecessary).
- UUID generation per entity — rejected (doesn't map to existing entities).

---

### R6: PushOnlySyncStrategy Implementation

**Task**: Design the default strategy implementation that pushes local changes to remote.

**Decision**: `PushOnlySyncStrategy<T>` lives in the data layer (generated or in Zuraffa core library). It:

1. Queries `SyncMetadataStore` for records with `SyncStatus.pending` or `SyncStatus.failed`
2. Batch-fetches the corresponding entities from `_localDataSource` using the keys
3. For each batch (default 50):
   - Sets status to `SyncStatus.syncing`
   - Calls `_remoteDataSource.create()` or `_remoteDataSource.update()` based on metadata
   - On success: sets status to `SyncStatus.synced`
   - On failure: increments `retryCount`, sets `lastError`, calculates backoff delay
   - If `retryCount >= maxRetries`: sets status to `SyncStatus.failed`
4. Handles tombstones: detects `deletedAt != null`, calls `_remoteDataSource.delete()`, removes metadata entry

Backoff calculation: `delay = min(baseDelay * 2^retryCount, maxDelay)` where baseDelay=1s, maxDelay=60s, maxRetries=5.

**Rationale**: Push-only is the safest default. It ensures local changes reach the remote without the complexity of conflict resolution. Bidirectional is opt-in via `--bidirectional`.

**Alternatives considered**:
- Immediate push (no batching) — rejected for remote protection (could overwhelm with thousands of records).
- Real-time sync (WebSocket) — rejected (out of scope, eventual consistency is sufficient).

---

### R7: DI Registration for Sync-Enabled Repositories

**Task**: Design how the DI plugin registers sync-enabled repositories.

**Decision**: Extend `_generateRepositoryDI` in `di_plugin.dart` to handle `config.enableSync`:

When sync is enabled, register:
1. `_remoteDataSource` (lazy singleton) — as usual
2. `_localDataSource` (singleton async, opens Hive box) — as usual
3. `_syncMetadataStore` (singleton async, opens metadata Hive box) — NEW
4. `_syncStrategy` (lazy singleton) — NEW
5. Repository (lazy singleton) — constructor takes all 4 dependencies

```dart
// Generated DI for sync-enabled repository:
getIt.registerSingletonAsync<EngagementEventLocalDataSource>(() async {
  final box = await Hive.openBox<EngagementEvent>('engagement_events');
  return EngagementEventLocalDataSource(box);
});
getIt.registerLazySingleton<EngagementEventRemoteDataSource>(
  () => EngagementEventRemoteDataSource(),
);
getIt.registerSingletonAsync<SyncMetadataStore>(() async {
  final box = await Hive.openBox<SyncMetadata>('sync_metadata_engagement_event');
  return SyncMetadataStore(box);
});
getIt.registerLazySingleton<SyncStrategy<EngagementEvent>>(
  () => PushOnlySyncStrategy<EngagementEvent>(
    getIt<EngagementEventLocalDataSource>(),
    getIt<EngagementEventRemoteDataSource>(),
    getIt<SyncMetadataStore>(),
  ),
);
getIt.registerLazySingleton<EngagementEventRepository>(
  () => DataEngagementEventRepository(
    getIt<EngagementEventLocalDataSource>(),
    getIt<EngagementEventRemoteDataSource>(),
    getIt<SyncMetadataStore>(),
    getIt<SyncStrategy<EngagementEvent>>(),
  ),
);
```

**Rationale**: Follows the exact same pattern as cache-enabled DI registration (which registers remote, local, cache policy, and repository). The metadata store is a singleton async because it needs to open a Hive box.

**Alternatives considered**:
- Manual DI registration — rejected (must be auto-generated for framework consistency).
- Factory registration for strategy — rejected (strategies are typically stateless, singleton is fine).

---

### R8: GeneratorConfig Extensions

**Task**: Extend GeneratorConfig to support sync-related fields.

**Decision**: Add the following fields to `GeneratorConfig`:

```dart
bool enableSync;           // --sync flag
String syncDirection;      // 'push' (default) or 'bidirectional'
int syncBatchSize;         // default: 50
int syncMaxRetries;        // default: 5
int syncBackoffBaseMs;     // default: 1000
int syncBackoffMaxMs;      // default: 60000
```

These flow through the plan resolver → plugin context → plugin generation, exactly as `enableCache`, `cachePolicy`, `ttlMinutes` do.

**Rationale**: Mirrors the existing `enableCache` pattern. The config is serializable (for `--from-json` support) and appears in the `--plan` output.

---

### R9: Compatibility with Cache Plugin

**Task**: Ensure sync and cache can coexist on the same entity.

**Decision**: Sync and cache are mutually exclusive at the repository level. The repository generator checks:
- If `enableCache` → generates cached repository methods (remote-first)
- If `enableSync` → generates synced repository methods (local-first)
- If both → ERROR: "Cannot enable both --cache and --sync on the same entity. Cache is remote-first; sync is local-first. They are architecturally incompatible."

**Rationale**: Cache and sync represent opposite data flow strategies:
- Cache: remote is source of truth, local is a temporary cache with TTL
- Sync: local is source of truth, remote is a sync target

Mixing them would create contradictory behavior (which is the source of truth?). The shared infrastructure (Hive box, local datasource) can be reused, but the repository strategy must be one or the other.

**Alternatives considered**:
- Allowing both with layered strategy — rejected (complexity, contradictory semantics).
- Making sync a superset of cache — rejected (different data flow direction).
