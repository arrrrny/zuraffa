# Tasks: Offline-First Sync Plugin

**Input**: Design documents from `/specs/010-offline-first-sync/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — FR-014 explicitly requires generated tests.

**Organization**: Tasks grouped by user story. US1+US2 are combined into a single phase since they share the same repository generator (writes and reads are generated together).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Plugin Scaffolding)

**Purpose**: Create the SyncPlugin directory structure and register it in the plugin loader.

- [X] T001 Create plugin directory structure: `lib/src/plugins/sync/` with subdirs `builders/`, `capabilities/`, `generators/`
- [X] T002 Create `lib/src/commands/sync_command.dart` as a stub extending `PluginCommand` (mirrors `lib/src/commands/cache_command.dart`)
- [X] T003 Register `SyncPlugin` import and instantiation in `lib/src/cli/plugin_loader.dart` `_plugins()` list (after `CachePlugin`, position ~121)

---

## Phase 2: Foundational (Core Domain Types + Config)

**Purpose**: Core interfaces and types that ALL user stories depend on. These live in Zuraffa's core library and are exported via `lib/zuraffa.dart`.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Create `SyncStatus` enum in `lib/src/core/sync_status.dart` with values: `pending`, `syncing`, `synced`, `failed`
- [X] T005 [P] Create `SyncOperation` enum in `lib/src/core/sync_operation.dart` with values: `create`, `update`, `delete`
- [X] T006 [P] Create `SyncMetadata` Zorphy entity in `lib/src/core/sync_metadata.dart` with fields: `status:SyncStatus`, `retryCount:int`, `lastAttemptAt:DateTime?`, `lastError:String?`, `deletedAt:DateTime?`, `operation:SyncOperation`
- [X] T007 Create `SyncStrategy<T>` abstract class in `lib/src/core/sync_strategy.dart` with methods: `syncPending({CancelToken?})`, `pullRemote({CancelToken?})`, `getPendingCount()`, `getSyncStatus(String)`, `markPending(String, {SyncOperation})`, `markDeleted(String)` (see `contracts/sync-strategy.md`)
- [X] T008 [P] Create `SyncConfig` class in `lib/src/core/sync_config.dart` with fields: `batchSize:int` (default 50), `maxRetries:int` (default 5), `backoffBaseMs:int` (default 1000), `backoffMaxMs:int` (default 60000)
- [X] T009 [P] Create `SyncDirection` enum in `lib/src/core/sync_config.dart` with values: `push`, `bidirectional`
- [X] T010 Export all new core types in `lib/zuraffa.dart`: `sync_status.dart`, `sync_operation.dart`, `sync_metadata.dart`, `sync_strategy.dart`, `sync_config.dart`
- [X] T011 Add sync fields to `GeneratorConfig` in `lib/src/models/generator_config.dart`: `enableSync:bool`, `syncDirection:String` (default 'push'), `syncBatchSize:int` (default 50), `syncMaxRetries:int` (default 5), `syncBackoffBaseMs:int` (default 1000), `syncBackoffMaxMs:int` (default 60000). Update `copyWith` and `toJson`.
- [X] T012 Add `--sync` flag, `--bidirectional` flag, and sync config options to `lib/src/commands/make_command.dart` `_addCoreOptions()` and `_ignoredJsonOptionKeys`

**Checkpoint**: Core types available. GeneratorConfig supports sync. Ready for user story implementation.

---

## Phase 3: User Stories 1+2 — Synced Repository Generator (Priority: P1) 🎯 MVP

**Goal**: Generate a sync-enabled repository that writes to local first (instant, offline-capable) and reads from local only. This covers US1 (local-first writes) and US2 (local reads) — they share the same repository generator.

**Independent Test**: Generate an entity with `--sync`, call `create()` while offline → verify it writes to local instantly and returns. Call `get()` while offline → verify it reads from local instantly.

### Implementation

- [X] T013 [P] [US1] Create `SyncMetadataStore` class in `lib/src/plugins/sync/builders/sync_metadata_store.dart` with methods: `get(String)`, `put(String, SyncMetadata)`, `remove(String)`, `getKeysByStatus(SyncStatus)`, `countByStatus(SyncStatus)`, `clear()`. Uses `Box<SyncMetadata>` (see `contracts/sync-metadata.md`)
- [X] T014 [US1] Create entity key resolver utility in `lib/src/plugins/sync/builders/sync_key_resolver.dart` — analyzes entity via `EntityAnalyzer` to determine if entity has `id` field; generates `_syncKey(entity)` method returning `entity.id` or `entity.hashCode.toString()`
- [X] T015 [US1] Create `implementation_generator_synced.dart` as `part of 'implementation_generator.dart'` in `lib/src/plugins/repository/generators/` — extension on `RepositoryImplementationGenerator` with methods: `_generateSyncedMethod()`, `_buildSyncedCreateBody()`, `_buildSyncedUpdateBody()`, `_buildSyncedDeleteBody()`, `_buildSyncedGetBody()`, `_buildSyncedGetListBody()` (mirrors `implementation_generator_cached.dart` structure)
- [X] T016 [US1] Update `RepositoryImplementationGenerator.generate()` in `lib/src/plugins/repository/generators/implementation_generator.dart` to route to synced methods when `config.enableSync` is true (add `else if (config.enableSync)` branch alongside existing `config.enableCache`)
- [X] T017 [US1] Update repository constructor/fields generation in `implementation_generator.dart` to add 4 dependencies when `enableSync`: `_localDataSource`, `_remoteDataSource`, `_syncMetadataStore`, `_syncStrategy` (mirrors how cached mode adds `_remoteDataSource`, `_localDataSource`, `_cachePolicy`)
- [X] T018 [US1] Add mutual exclusivity check: if `config.enableCache && config.enableSync`, throw `ArgumentError('Cannot enable both --cache and --sync')` in `RepositoryImplementationGenerator.generate()`
- [X] T019 [US2] Verify synced `get()` and `getList()` method bodies delegate to `_localDataSource` only with no network calls (part of T015, verify independently)
- [X] T020 [US1] Update `RepositoryPlugin.generateWithContext()` in `lib/src/plugins/repository/repository_plugin.dart` to pass `enableSync` and sync config fields from context to `GeneratorConfig`

**Checkpoint**: `zfa make <Entity> --sync --data --datasource` generates a sync-enabled repository with local-first writes and local-only reads. Push strategy is not yet functional (US3).

---

## Phase 4: User Story 3 — PushOnlySyncStrategy + Sync UseCase (Priority: P1)

**Goal**: Implement the default push strategy that detects pending local changes, transmits them to remote with retry/backoff, and updates sync status. Also generate the `Sync<Entity>UseCase` for manual triggering.

**Independent Test**: Generate an entity with `--sync`, create several entities while offline, bring online, trigger sync via use case → verify all pending entities are transmitted to remote and marked as `synced`.

### Implementation

- [X] T021 [US3] Create `PushOnlySyncStrategy<T>` in `lib/src/plugins/sync/builders/push_only_sync_strategy.dart` implementing `SyncStrategy<T>` with constructor taking `LocalDataSource<T>`, `RemoteDataSource<T>`, `SyncMetadataStore`, `SyncConfig`
- [X] T022 [US3] Implement `syncPending()` in `PushOnlySyncStrategy`: query metadata store for pending/failed keys, batch-fetch entities from local, transmit to remote via appropriate method based on `SyncOperation`, update status on success/failure, handle tombstones for deletes
- [X] T023 [US3] Implement retry with exponential backoff in `PushOnlySyncStrategy`: on failure, increment `retryCount`, calculate delay as `min(backoffBaseMs * 2^retryCount, backoffMaxMs)`, set status back to `pending` if retries remaining, `failed` if exhausted
- [X] T024 [US3] Implement tombstone handling in `PushOnlySyncStrategy.syncPending()`: detect `deletedAt != null` metadata entries, call `remoteDataSource.delete(key)`, remove metadata entry on success
- [X] T025 [US3] Implement `markPending()` and `markDeleted()` in `PushOnlySyncStrategy`: create/update `SyncMetadata` entries in the metadata store
- [X] T026 [US3] Implement `getPendingCount()` and `getSyncStatus()` in `PushOnlySyncStrategy`: delegate to metadata store queries
- [X] T027 [US3] Implement `pullRemote()` in `PushOnlySyncStrategy` to throw `UnimplementedError('PushOnlySyncStrategy does not support pull')`
- [X] T028 [P] [US3] Add `CancelToken` support to `syncPending()`: check `cancelToken?.throwIfCancelled()` between each batch and between each record within a batch
- [X] T029 [US3] Add logging to `PushOnlySyncStrategy` via `Loggable` mixin: log sync attempts, successes, failures, retry counts, batch progress
- [X] T030 [US3] Create `SyncEntityUseCase` generator in `lib/src/plugins/sync/generators/sync_usecase_generator.dart` — generates `Sync<Entity>UseCase extends UseCase<void, NoParams>` that calls `repository.syncPending(cancelToken)` (mirrors existing use case generators)
- [X] T031 [US3] Wire `Sync<Entity>UseCase` generation into the sync plugin flow so it's generated when `--sync --with=usecase` (or `--sync` with CRUD preset)

**Checkpoint**: Full push sync works. Write locally → trigger sync → records appear on remote.

---

## Phase 5: User Story 4 — SyncPlugin + CLI + DI Registration (Priority: P2)

**Goal**: Build the standalone SyncPlugin (mirroring CachePlugin), CLI command (`zfa sync`), file generation via SyncBuilder, capabilities, and DI registration for sync-enabled repositories.

**Independent Test**: Run `zfa sync enable <Entity>` standalone → verify it generates sync infrastructure. Run `zfa make <Entity> --sync --di` → verify DI registers local, remote, metadata store, strategy, and repository.

### Implementation

- [X] T032 [US4] Create `SyncBuilder` class in `lib/src/plugins/sync/builders/sync_builder.dart` — generates: sync metadata Hive box init file (`{entity}_sync.dart`), `SyncMetadata` Hive adapter registration, sync strategy factory function. Mirrors `CacheBuilder` structure.
- [X] T033 [US4] Create `SyncPlugin` class in `lib/src/plugins/sync/sync_plugin.dart` extending `FileGeneratorPlugin` implementing `CliAwarePlugin` — with `id='sync'`, `name='Sync Plugin'`, `capabilities`, `configSchema` (sync-direction, sync-batch-size, sync-max-retries). Set `runAfter` to `['datasource', 'repository']`
- [X] T034 [US4] Create `CreateSyncCapability` in `lib/src/plugins/sync/capabilities/create_sync_capability.dart` — enables sync on entity (like `CreateCacheCapability`). Handles `zfa sync enable <Entity>` and `--sync` flag routing.
- [X] T035 [US4] Create `CreateSyncStatusCapability` in `lib/src/plugins/sync/capabilities/create_sync_status_capability.dart` — initializes sync metadata store and registers Hive adapter (like `CreateCacheAdapterCapability`). Handles `zfa sync status <Entity>`.
- [X] T036 [US4] Complete `SyncCommand` in `lib/src/commands/sync_command.dart` — add subcommands `enable` and `status`, add options for `--direction`, `--batch-size`, `--max-retries`. Wire to capabilities.
- [X] T037 [US4] Update `SyncPlugin.generateWithContext()` to build `GeneratorConfig` with sync fields from context (mirrors `CachePlugin.generateWithContext()`)
- [X] T038 [US4] Update `_generateRepositoryDI()` in `lib/src/plugins/di/di_plugin.dart` to handle `config.enableSync`: register `_syncMetadataStore` (singleton async, opens Hive box), `_syncStrategy` (lazy singleton, `PushOnlySyncStrategy` or `BidirectionalSyncStrategy`), and repository with 4-dependency constructor (mirrors cached DI in L469-L502)
- [X] T039 [US4] Update `_generateLocalDataSourceDI()` in `lib/src/plugins/di/di_plugin.dart` to generate local datasource registration when `config.enableSync` (same as `config.enableCache` — opens Hive box)
- [X] T040 [US4] Update `_generateRemoteDataSourceDI()` in `lib/src/plugins/di/di_plugin.dart` to generate remote datasource registration when `config.enableSync` (same pattern as existing)
- [X] T041 [US4] Generate `Sync<Entity>UseCase` DI registration in `di_plugin.dart` when `config.enableSync && config.generateDi` — register as factory

**Checkpoint**: `zfa make <Entity> --sync --di` generates complete, wired, compilable offline-first stack. `zfa sync enable <Entity>` works standalone.

---

## Phase 6: User Story 5 — BidirectionalSyncStrategy (Priority: P2)

**Goal**: Implement bidirectional sync that pulls remote data into local after pushing local changes, with configurable conflict resolution.

**Independent Test**: Generate an entity with `--sync --bidirectional`, modify data on remote, trigger sync → verify local is updated with remote changes.

### Implementation

- [X] T042 [P] [US5] Create `ConflictResolver<T>` abstract interface in `lib/src/core/conflict_resolver.dart` with method: `Future<T> resolve(T? local, T remote)` — default implementation `RemoteWinsConflictResolver` returns `remote`
- [X] T043 [US5] Create `BidirectionalSyncStrategy<T>` in `lib/src/plugins/sync/builders/bidirectional_sync_strategy.dart` extending `PushOnlySyncStrategy<T>` — adds `pullRemote()` implementation and `ConflictResolver<T>` dependency
- [X] T044 [US5] Implement `pullRemote()` in `BidirectionalSyncStrategy`: call `remoteDataSource.getList()`, for each remote record check local status, resolve conflicts via `ConflictResolver`, save to local + mark `synced`, delete local records not in remote result set (if they were `synced`)
- [X] T045 [US5] Update `SyncPlugin.configSchema` to include `bidirectional` as a sync-direction option
- [X] T046 [US5] Update DI generation to select `BidirectionalSyncStrategy` when `config.syncDirection == 'bidirectional'` (instead of `PushOnlySyncStrategy`)

**Checkpoint**: Bidirectional sync works. Push local → pull remote → conflicts resolved.

---

## Phase 7: Tests (Integration + Unit)

**Purpose**: Tests for the sync infrastructure (FR-014 requires generated tests). Integration tests follow the existing `RegressionWorkspace` pattern used in `test/integration/` and `test/regression/`.

### Unit Tests

- [X] T047 [P] Create `test/plugins/sync/sync_plugin_test.dart` — test plugin registration, config schema, capability resolution
- [X] T048 [P] Create `test/plugins/sync/sync_builder_test.dart` — test file generation: metadata store init, strategy factory, Hive adapter registration
- [X] T049 [P] Create `test/plugins/sync/push_only_sync_strategy_test.dart` — test push sync success, push sync failure with retry, tombstone handling, batch processing, cancel token
- [X] T050 [P] Create `test/plugins/sync/bidirectional_sync_strategy_test.dart` — test pull sync, conflict resolution (remote-wins), local record deletion when removed from remote

### Integration Tests

- [X] T051 [P] Create `test/integration/sync_workflow_test.dart` — full end-to-end: create workspace, write entity stub, generate with `enableSync: true`, verify all files exist (sync-enabled repository, local datasource, remote datasource, sync metadata store, sync strategy, sync use case), verify repository content has local-first write methods + local-only read methods + sync delegation. Run `dart analyze` on generated output. Follow pattern from `test/integration/full_entity_workflow_test.dart`.
- [X] T052 [P] Create `test/integration/sync_with_di_test.dart` — generate entity with `enableSync + generateDi`, verify DI files register: local datasource (singleton async with Hive box), remote datasource (lazy singleton), sync metadata store (singleton async), sync strategy (lazy singleton), repository (4-dep constructor), sync use case (factory). Follow pattern from `test/regression/di_registration_test.dart`.
- [X] T053 [P] Create `test/integration/sync_mutual_exclusivity_test.dart` — verify that generating with both `enableCache + enableSync` produces an error. Follow pattern from `test/integration/cache_adapter_test.dart`.
- [X] T054 [P] Create `test/regression/sync_repository_test.dart` — verify generated repository method bodies: `create()` writes to local + marks pending, `get()` reads local only (no remote call), `delete()` tombstones, `syncPending()` delegates to strategy. Verify repository constructor takes 4 dependencies (local, remote, metadataStore, syncStrategy).

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T055 [P] Update Zuraffa example project: add a sync-enabled entity to `example/` demonstrating the full flow
- [X] T056 Add append/revert support to synced repository generator — `zfa make <Entity> --sync --append` should add sync methods to existing repository without destroying code
- [X] T057 [P] Update `.zfa.json` documentation and CLI help text for `--sync`, `--bidirectional`, and sync config options
- [X] T058 Run `quickstart.md` validation: follow every example in quickstart.md against a real entity and verify it works end-to-end
- [X] T059 Verify `--cache` and `--sync` mutual exclusivity error message is clear and actionable

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1+US2)**: Depends on Phase 2 — MVP
- **Phase 4 (US3)**: Depends on Phase 3 — needs the synced repository to exist
- **Phase 5 (US4)**: Depends on Phases 3+4 — needs repository generator + strategy
- **Phase 6 (US5)**: Depends on Phase 4 — extends PushOnlySyncStrategy
- **Phase 7 (Tests)**: Can start after Phase 3, but ideally after Phase 6
- **Phase 8 (Polish)**: Depends on all phases complete

### User Story Dependencies

- **US1+US2 (P1)**: Can start after Foundational — No dependencies on other stories
- **US3 (P1)**: Depends on US1+US2 (needs synced repository to push from)
- **US4 (P2)**: Depends on US1-US3 (needs all components to wire in DI)
- **US5 (P2)**: Depends on US3 (extends PushOnlySyncStrategy)

### Within Each Phase

- Core types before implementations
- Interfaces before concrete classes
- Repository generator before strategy (strategy is injected into repository)
- Strategy before DI (DI registers the strategy)
- Implementation before tests

### Parallel Opportunities

- Phase 2: T004-T009 all touch different files (parallel)
- Phase 3: T013 and T014 are independent (parallel)
- Phase 4: T028 (CancelToken) can parallel with T029 (logging)
- Phase 5: T034 and T035 are independent capabilities (parallel)
- Phase 6: T042 (ConflictResolver) can parallel with other prep
- Phase 7: All test files are independent (parallel)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all core type creation in parallel:
Task: "Create SyncStatus enum in lib/src/core/sync_status.dart"
Task: "Create SyncOperation enum in lib/src/core/sync_operation.dart"
Task: "Create SyncMetadata class in lib/src/core/sync_metadata.dart"
Task: "Create SyncConfig class in lib/src/core/sync_config.dart"
```

---

## Implementation Strategy

### MVP First (User Stories 1+2+3)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: US1+US2 — Synced Repository Generator
4. Complete Phase 4: US3 — PushOnlySyncStrategy
5. **STOP and VALIDATE**: Generate a test entity with `--sync`, verify local-first writes work offline, verify push sync transmits to remote
6. This is a functional MVP — offline-first writes + reads + background push

### Incremental Delivery

1. Setup + Foundational → Core types ready
2. - US1+US2 → Local-first repository works (writes/reads instant, offline)
3. - US3 → Push sync works (background transmission to remote) — **MVP!**
4. - US4 → Plugin infrastructure + DI + CLI command
5. - US5 → Bidirectional sync with pull + conflict resolution
6. Polish → Tests, docs, example project

---

## Notes

- All generated code must follow Clean Architecture: domain interfaces in core, implementations in data layer
- Domain entity stays pure — NO sync infrastructure fields (all tracking in SyncMetadataStore)
- SyncPlugin mirrors CachePlugin structure exactly — same plugin/command/builder/capability pattern
- `--cache` and `--sync` are mutually exclusive (remote-first vs. local-first)
- Entity key resolution: use `entity.id` if present, else `entity.hashCode.toString()`
- Retry: exponential backoff, base 1s, max 60s, 5 max retries
- Batch size default: 50 records
