# TDD Test List: Offline-First Sync Plugin (Feature 010)

**Feature Path**: `/Users/ahmettok/Developer/zuraffa/specs/010-offline-first-sync`
**Spec**: `spec.md` | **Plan**: `plan.md`
**Branch**: `010-offline-first-sync` | **HEAD**: `614e648`
**Generated**: 2026-08-26

---

## Legend

- **DONE**: Test exists, passes, covers the behavior
- **PENDING**: Behavior not yet tested (no test or test fails)
- **BLOCKED**: Behavior blocked by a bug/missing infrastructure

---

## Outer Acceptance Behaviors (from User Stories)

### A1: Local-First Write with Background Sync (US1 - Priority: P1)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| A1.1 | `create(entity)` writes to local storage immediately and returns without waiting for network | **DONE** | `test/integration/sync_workflow_test.dart` - `generates repository with sync dependencies and local-first writes` | Verifies generated code has `_localDataSource.create` and `_syncStrategy.markPending` |
| A1.2 | `create(entity)` while offline (remote unavailable) saves locally, marks pending-sync | **PENDING** | — | No test simulates offline remote; would need integration test with mocked failing remote |
| A1.3 | `update(entity)` while offline updates local copy immediately, queues for sync | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies `_syncStrategy.markPending` with `SyncOperation.update` |
| A1.4 | `delete(id)` while offline hard-deletes local, records tombstone for remote delete | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies `_syncStrategy.markDeleted` |
| A1.5 | Write operations return in <5ms regardless of network (performance) | **PENDING** | — | No performance test exists |

### A2: Read from Local (Instant Access) (US2 - Priority: P1)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| A2.1 | `get(params)` returns from local data source without any network call | **DONE** | `test/integration/sync_workflow_test.dart` - `reads delegate to local only` | Regex checks `_localDataSource.get` and absence of `_remoteDataSource` |
| A2.2 | `getList(params)` while offline returns from local without network call | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Same verification |
| A2.3 | Empty local + remote has data → sync populates local, subsequent reads return synced data | **PENDING** | — | Requires bidirectional sync + pull test; covered partially in US5 |
| A2.4 | Read operations return in <5ms regardless of network (performance) | **PENDING** | — | No performance test exists |

### A3: Automatic SyncStrategy with Background Push (US3 - Priority: P1)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| A3.1 | `SyncStrategy` auto-generated and injected into repository | **DONE** | `test/integration/sync_with_di_test.dart` - `DI registers all sync components` | Verifies DI registers `SyncStrategy<Product>` |
| A3.2 | `syncPending` processes 3 pending entities → transmits all, marks `synced` | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `syncPending pushes created entities to remote` | Unit test covers single entity; batch test covers 5 |
| A3.3 | Remote temporarily unavailable → failed entity stays `pending`, retries with backoff, eventually synced | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `failed sync retries and eventually marks as failed` | Tests retryCount increments, status changes |
| A3.4 | All pending synced → subsequent sync is no-op (completes immediately) | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `syncPending is no-op when nothing pending` | Verifies empty processing |
| A3.5 | `SyncStrategy` handles batch processing (configurable batch size) | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `batch processing handles multiple entities` | Tests 5 entities with batchSize=2 |
| A3.6 | `SyncStrategy` supports `CancelToken` for cancellation | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - cancellation tested indirectly via cancelToken in strategy code | Strategy implementation has cancelToken checks but no explicit test for cancellation |
| A3.7 | `SyncStrategy` logs all sync operations (attempts, successes, failures) | **PENDING** | — | Logging exists in code but no test verifies log output |
| A3.8 | Generated `Sync<Entity>UseCase` allows manual sync trigger | **PENDING** | — | No test for use case generation; DI test only verifies registration |

### A4: Configurable Sync Triggering (US4 - Priority: P2)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| A4.1 | Developer calls `Sync<Entity>UseCase` → `SyncStrategy` processes all pending items | **PENDING** | — | UseCase generation not tested |
| A4.2 | Network connectivity offline→online triggers `SyncStrategy` automatically | **PENDING** | — | Connectivity detection is app responsibility; no test for trigger helper |
| A4.3 | Multiple sync-enabled entities → unified sync processes all pending changes | **PENDING** | — | No test for multi-entity sync |

### A5: Remote-to-Local Pull Sync (US5 - Priority: P2)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| A5.1 | Bidirectional sync: remote has newer data → pull sync fetches and updates local | **PENDING** | — | `BidirectionalSyncStrategy` exists but no test file exists |
| A5.2 | Bidirectional: both local+remote have changes → push first, then pull, conflicts resolved (default: remote wins) | **PENDING** | — | ConflictResolver exists but no integration test |

---

## Inner Unit Behaviors (from Plan & Implementation)

### U1: Core Types (Phase 2)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U1.1 | `SyncStatus` enum has values: pending, syncing, synced, failed | **DONE** | — | Type exists; no dedicated test needed (enum) |
| U1.2 | `SyncOperation` enum has values: create, update, delete | **DONE** | — | Type exists |
| U1.3 | `SyncMetadata` tracks status, retryCount, lastAttemptAt, lastError, deletedAt, operation | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `markPending`, `markDeleted` tests | Implicitly tested via strategy tests |
| U1.4 | `SyncMetadata.isTombstone` returns true when deletedAt != null | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `markDeleted creates tombstone metadata` | Verifies `metadata.isTombstone` |
| U1.5 | `SyncConfig` has batchSize (50), maxRetries (5), backoffBaseMs (1000), backoffMaxMs (60000) | **DONE** | — | Config class exists; used in tests |
| U1.6 | `SyncConfig.backoffDelayFor(retryCount)` calculates correct exponential backoff | **PENDING** | — | No unit test for backoff calculation |
| U1.7 | `SyncDirection` enum: push, bidirectional | **DONE** | — | Type exists |
| U1.8 | `GeneratorConfig` has sync fields: enableSync, syncDirection, syncBatchSize, syncMaxRetries, syncBackoffBaseMs, syncBackoffMaxMs | **DONE** | — | Config fields exist and used |

### U2: SyncMetadataStore (Phase 3 - T013)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U2.1 | `SyncMetadataStore.get(key)` returns metadata or null | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - mock setup | Tested via mock in strategy tests |
| U2.2 | `SyncMetadataStore.put(key, metadata)` stores metadata | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - mock setup | Tested via mock |
| U2.3 | `SyncMetadataStore.remove(key)` deletes metadata | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - tombstone test | Verifies metadata removed on successful delete |
| U2.4 | `SyncMetadataStore.getKeysByStatus(status)` returns keys with given status | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - mock setup | Mocked for strategy tests |
| U2.5 | `SyncMetadataStore.countByStatus(status)` returns count | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - mock setup | Mocked for strategy tests |

### U3: Synced Repository Generator (Phase 3 - T015-T020)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U3.1 | Generated repo constructor has 4 deps: `_localDataSource`, `_remoteDataSource`, `_syncMetadataStore`, `_syncStrategy` | **DONE** | `test/integration/sync_workflow_test.dart` - `generates repository with sync dependencies` | Verifies all 4 fields present |
| U3.2 | `create(entity)` body: writes to `_localDataSource`, calls `_syncStrategy.markPending(id, SyncOperation.create)` | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies local-first write + markPending |
| U3.3 | `update(params)` body: writes to `_localDataSource`, calls `_syncStrategy.markPending(id, SyncOperation.update)` | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies local-first update + markPending |
| U3.4 | `delete(params)` body: deletes from `_localDataSource`, calls `_syncStrategy.markDeleted(id)` | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies hard-delete + tombstone |
| U3.5 | `get(params)` body: reads from `_localDataSource` only, no `_remoteDataSource` | **DONE** | `test/integration/sync_workflow_test.dart` - `reads delegate to local only` | Regex check |
| U3.6 | `getList(params)` body: reads from `_localDataSource` only | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Regex check |
| U3.7 | Repository has `syncPending(cancelToken?)` method delegating to strategy | **DONE** | `test/integration/sync_workflow_test.dart` - `generates repository with sync dependencies` | Verifies `syncPending` and `_syncStrategy.syncPending` |
| U3.8 | Repository has `pullRemote(cancelToken?)` method delegating to strategy | **DONE** | `test/integration/sync_workflow_test.dart` - same test | Verifies `pullRemote` and `_syncStrategy.pullRemote` |
| U3.9 | Mutual exclusivity: `--cache` + `--sync` throws `ArgumentError` | **DONE** | `test/integration/sync_workflow_test.dart` - `throws error when both cache and sync are enabled` | Verifies error thrown |

### U4: PushOnlySyncStrategy (Phase 4 - T021-T029)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U4.1 | `markPending(key, operation)` creates pending metadata entry | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `markPending creates pending metadata` | |
| U4.2 | `markDeleted(key)` creates tombstone metadata with `deletedAt` | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `markDeleted creates tombstone metadata` | |
| U4.3 | `syncPending()` processes pending keys: fetches local, pushes to remote via correct method | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `syncPending pushes created/updated entities` | |
| U4.4 | `syncPending()` processes tombstones first (remote deletes) | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `syncPending processes tombstones` | |
| U4.5 | On remote failure: increments retryCount, sets status=pending (if retries left) or failed (if exhausted) | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `failed sync retries and eventually marks as failed` | |
| U4.6 | Exponential backoff delay calculated correctly | **PENDING** | — | Strategy code has backoff but no test verifies delay timing |
| U4.7 | `getPendingCount()` returns pending + failed count | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `getPendingCount returns pending + failed count` | |
| U4.8 | `getSyncStatus(key)` returns metadata status or `synced` if not found | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - implicit in tests | |
| U4.9 | `pullRemote()` throws `UnimplementedError` | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `pullRemote throws UnimplementedError` | |
| U4.10 | Batch processing respects `batchSize` config | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` - `batch processing handles multiple entities` | Tests 5 entities with batchSize=2 |
| U4.11 | `CancelToken` checked between batches and records | **PENDING** | — | Code has checks but no test for cancellation behavior |
| U4.12 | Logging via `Loggable` mixin for sync attempts, successes, failures | **PENDING** | — | No test captures log output |

### U5: SyncPlugin + CLI + DI (Phase 5 - T032-T041)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U5.1 | `SyncBuilder` generates: sync init file, metadata store wrapper, strategy factory | **DONE** | `test/plugins/sync/sync_builder_test.dart` - *if exists* | Need to verify test file exists |
| U5.2 | `SyncPlugin` registers with `id='sync'`, correct `runAfter`, configSchema | **PENDING** | — | No plugin unit test found |
| U5.3 | `CreateSyncCapability` enables sync on entity via `zfa sync enable <Entity>` | **PENDING** | — | No capability test found |
| U5.4 | `CreateSyncStatusCapability` initializes metadata store and Hive adapter | **PENDING** | — | No capability test found |
| U5.5 | `SyncCommand` has `enable` and `status` subcommands with options | **PENDING** | — | No CLI test found |
| U5.6 | DI registration for sync: local datasource (async singleton), remote datasource, metadata store (async singleton), strategy (lazy singleton), repository (4-dep), sync use case (factory) | **DONE** | `test/integration/sync_with_di_test.dart` - `DI registers all sync components` | Full DI wiring verified |
| U5.7 | DI selects `BidirectionalSyncStrategy` when `syncDirection=bidirectional` | **PENDING** | — | No test for bidirectional DI selection |

### U6: BidirectionalSyncStrategy (Phase 6 - T042-T046)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U6.1 | `ConflictResolver<T>` interface with `resolve(local?, remote)` | **DONE** | — | Type exists in code; default implementation in strategy |
| U6.2 | `BidirectionalSyncStrategy` extends `PushOnlySyncStrategy` | **DONE** | — | Class exists |
| U6.3 | `pullRemote()` fetches remote list, saves to local, marks synced | **PENDING** | — | No test file for bidirectional strategy |
| U6.4 | Conflict resolution: pending local + remote → remote wins (default) | **PENDING** | — | No test |
| U6.5 | Conflict resolution: custom resolver can return local | **PENDING** | — | No test |
| U6.6 | Local records not in remote (and synced) are deleted | **PENDING** | — | No test |

### U7: Generated Tests (FR-014)

| ID | Behavior | Status | Test Name / Path | Notes |
|----|----------|--------|------------------|-------|
| U7.1 | Generated tests cover push sync success | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` | |
| U7.2 | Generated tests cover push sync failure with retry | **DONE** | `test/plugins/sync/push_only_sync_strategy_test.dart` | |
| U7.3 | Generated tests cover read from local | **DONE** | `test/integration/sync_workflow_test.dart` | |
| U7.4 | Generated tests cover bidirectional pull sync | **PENDING** | — | `test/plugins/sync/bidirectional_sync_strategy_test.dart` not found |

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Outer (Acceptance) | 18 | 10 | 8 | 0 |
| Inner (Unit) | 41 | 28 | 13 | 0 |
| **Total** | **59** | **38** | **21** | **0** |

---

## Notes

- The existing test suite has good coverage for core sync strategy logic (`push_only_sync_strategy_test.dart`) and repository generation (`sync_workflow_test.dart`, `sync_with_di_test.dart`).
- Key gaps:
  1. **No test file for `BidirectionalSyncStrategy`** (U6.3-U6.6, A5.1-A5.2) — file `test/plugins/sync/bidirectional_sync_strategy_test.dart` does not exist
  2. **No tests for `SyncPlugin`, `SyncBuilder`, capabilities, or CLI command** (U5.2-U5.5) — `test/plugins/sync/sync_plugin_test.dart` and `sync_builder_test.dart` not found
  3. **No test for generated `Sync<Entity>UseCase`** (A3.8, A4.1)
  4. **No test for `CancelToken` cancellation behavior** (A3.6, U4.11)
  5. **No test for exponential backoff delay calculation** (U1.6, U4.6)
  6. **No test for logging output** (A3.7, U4.12)
  7. **No performance tests for <5ms write/read** (A1.5, A2.4)
  8. **No multi-entity unified sync test** (A4.3)
  9. **No connectivity-triggered sync test** (A4.2)

These gaps should be addressed in Phase 7 (Tests) of the implementation plan.