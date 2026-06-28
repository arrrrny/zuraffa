# Feature Specification: Offline-First Sync Plugin

**Feature Branch**: `010-offline-first-sync`

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "Investigate all the zfa commands and plugins. Currently we have a way of adding local datasource and remote datasource both and also cache plugin. Just like the cache plugin handles all the steps automatically of fetching remote, updating local if we receive data from remote, and invalidate cache, I want either a new sync plugin or a flag to create the opposite direction to TRULY IMPLEMENT offline-first architecture. This is Zuraffa, a Clean Architecture Framework. RIGIDLY APPLY SOLID PRINCIPLES and DRY, CLEAN CODE generated is MANDATORY. There MUST be a textbook definition local-first persistence structure implying Clean Architecture."

## Clarifications

### Session 2026-06-28

- Q: Should sync be a standalone plugin (like cache) or just a flag? → A: Standalone `SyncPlugin` following `CachePlugin` structure — separate plugin class, CLI command (`zfa sync <Entity>`), builder, and capabilities. The `--sync` flag on `zfa make` triggers this plugin internally, exactly as `--cache` triggers `CachePlugin`.
- Q: Where should sync status live — on the entity or in a separate store? → A: Separate sync metadata store (Hive box), keyed by entity `id` (or `hashCode` fallback for entities without `id`). Domain entity stays pure — no infrastructure fields.
- Q: How should offline deletions be tracked? → A: Tombstone in sync metadata store only — record is hard-deleted from local immediately, metadata entry records `deletedAt` timestamp to signal a pending remote deletion. No soft-delete flag pollutes the local data box.
- Q: Should sync logic be embedded in the repository or a separate component? → A: Fully embedded in the repository (like cache plugin), using the Strategy pattern. The repository delegates the _how_ of sync to an injectable `SyncStrategy` — exactly as the cache-enabled repository delegates freshness to `CachePolicy`. Swap strategy to change behavior without touching generated code.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Local-First Write with Background Sync (Priority: P1)

As a developer using Zuraffa, when I generate an entity with the sync plugin enabled, I want all write operations (create, update, delete) to write to the local data source immediately and return instantly, while the injected `SyncStrategy` transparently pushes those changes to the remote data source. This means the app never blocks waiting for network responses, and the user's data is always persisted locally first.

**Why this priority**: This is the core value proposition of offline-first architecture. Without local-first writes, no offline capability exists. Everything else depends on this.

**Independent Test**: Generate an entity with `--sync`, call `create()`, and verify: (1) the entity is immediately persisted to local storage, (2) the method returns without waiting for network, (3) the `SyncStrategy` eventually pushes the entity to the remote data source.

**Acceptance Scenarios**:

1. **Given** a sync-enabled repository, **When** `create(entity)` is called while online, **Then** the entity is saved to local storage immediately, the method returns the locally-saved entity, and the `SyncStrategy` pushes the entity to the remote data source within a reasonable time window.

2. **Given** a sync-enabled repository, **When** `create(entity)` is called while offline (remote unavailable), **Then** the entity is saved to local storage immediately, the method returns successfully, and the entity is marked as pending-sync so it will be transmitted when connectivity is restored.

3. **Given** a sync-enabled repository, **When** `update(entity)` is called while offline, **Then** the local copy is updated immediately, the change is queued for sync, and no data is lost.

4. **Given** a sync-enabled repository, **When** `delete(id)` is called while offline, **Then** the local copy is deleted (or tombstoned) immediately, the deletion is queued for sync, and the remote copy will be deleted when connectivity is restored.

---

### User Story 2 - Read from Local (Instant Access) (Priority: P1)

As a developer using Zuraffa, when I generate an entity with the sync plugin enabled, I want all read operations (`get`, `getList`) to read directly from the local data source and return instantly. The local data source is the primary source of truth. Remote data is pulled into local during sync, not during reads.

**Why this priority**: Instant reads are the second half of offline-first. Combined with local-first writes, this gives the app full offline operation capability. Reads must never block on network.

**Independent Test**: Generate an entity with `--sync`, populate local storage, call `get()` / `getList()` with the device in airplane mode, and verify data is returned instantly from local storage.

**Acceptance Scenarios**:

1. **Given** a sync-enabled repository with local data present, **When** `get(params)` is called, **Then** the entity is returned from the local data source without any network call.

2. **Given** a sync-enabled repository with local data present, **When** `getList(params)` is called while offline, **Then** the list is returned from the local data source without any network call.

3. **Given** a sync-enabled repository, **When** the local data source is empty but remote has data, **Then** a sync operation populates local storage, and subsequent reads return the synced data from local.

---

### User Story 3 - Automatic `SyncStrategy` with Background Push (Priority: P1)

As a developer using Zuraffa, when I generate an entity with the sync plugin enabled, I want a `SyncStrategy` to be automatically generated and injected into the repository. The strategy detects pending-local-changes (records that were written locally but not yet pushed to remote), transmits them to the remote data source, and marks them as synced upon success. Failed syncs are retried with exponential backoff.

**Why this priority**: Without an automatic `SyncStrategy`, local-first writes would accumulate indefinitely with no path to the remote. This replaces the manual, hacky `SyncEngagementEventsUseCase` pattern with a proper, reusable, framework-generated solution.

**Independent Test**: Generate an entity with `--sync`, create several entities while offline, bring the device online, trigger a sync operation, and verify all pending entities are transmitted to the remote data source and marked as synced.

**Acceptance Scenarios**:

1. **Given** a sync-enabled repository with 3 pending-sync entities in local storage, **When** a sync operation is triggered, **Then** all 3 entities are transmitted to the remote data source and their sync status is updated from `pending` to `synced`.

2. **Given** a sync-enabled repository, **When** the remote data source is temporarily unavailable during a sync attempt, **Then** the failed entity remains marked as `pending`, the `SyncStrategy` retries with backoff, and the entity is eventually synced when the remote becomes available.

3. **Given** a sync-enabled repository, **When** a sync operation is triggered and all pending entities are successfully transmitted, **Then** subsequent sync operations detect no pending entities and complete immediately (no-op).

---

### User Story 4 - Configurable Sync Triggering (Priority: P2)

As a developer using Zuraffa, I want to be able to trigger the `SyncStrategy` at appropriate times in my application lifecycle: on app start, on network connectivity restoration, periodically, or manually. The sync plugin should provide the infrastructure for these triggers without imposing a single trigger strategy.

**Why this priority**: Different apps need different sync strategies. The framework should provide the `SyncStrategy` and let the app decide when to trigger it. This replaces the hack where sync is manually called from `InitializeConfigsUseCase`.

**Independent Test**: Generate an entity with `--sync`, obtain the sync use case from DI, call it manually, and verify it processes all pending items. Then verify it can also be triggered automatically on connectivity restoration.

**Acceptance Scenarios**:

1. **Given** a sync-enabled entity, **When** the developer calls the generated `Sync<Entity>UseCase`, **Then** the `SyncStrategy` processes all pending-local-changes for that entity.

2. **Given** a sync-enabled entity, **When** network connectivity transitions from offline to online, **Then** the `SyncStrategy` can be configured to automatically trigger for that entity.

3. **Given** multiple sync-enabled entities, **When** the developer wants to sync all entities at once, **Then** a unified sync mechanism processes all pending changes across all sync-enabled entities.

---

### User Story 5 - Remote-to-Local Pull Sync (Priority: P2)

As a developer using Zuraffa, when I generate an entity with the sync plugin enabled and bidirectional mode, I want the `SyncStrategy` to also pull data from the remote data source and merge it into local storage. This ensures local storage stays fresh with server-side changes made by other clients or systems.

**Why this priority**: One-directional (push-only) sync covers the write path. Bidirectional sync completes the offline-first model by keeping local data fresh with remote changes. This is only needed when the entity has a remote `getList` implementation.

**Independent Test**: Generate an entity with `--sync --bidirectional`, modify data on the remote server, trigger a pull sync, and verify the local data source is updated with the remote changes.

**Acceptance Scenarios**:

1. **Given** a bidirectional sync-enabled entity, **When** the remote data source has newer data than local, **Then** a pull sync operation fetches the remote data and updates local storage.

2. **Given** a bidirectional sync-enabled entity, **When** both local and remote have changes, **Then** the push phase sends local changes first, then the pull phase fetches remote updates, and conflicts are resolved by a configurable strategy (default: remote wins for server-authoritative data).

---

### Edge Cases

- What happens when the local data source is full or corrupted? The `SyncStrategy` should log the error and continue operating; reads should still return whatever local data is available.
- What happens when two sync operations run concurrently for the same entity? The `SyncStrategy` must be idempotent or use locking to prevent duplicate remote transmissions.
- What happens when the remote returns a conflict (e.g., entity was deleted on the server)? The `SyncStrategy` should apply a conflict resolution strategy (configurable: remote-wins, local-wins, or custom) and update local state accordingly.
- What happens when an entity is created locally, then deleted locally before sync? The `SyncStrategy` should detect the tombstone in the metadata store, recognize the entity was never synced to remote (no prior `synced` status), and simply remove the metadata entry without attempting a remote delete (since the remote doesn't know about it yet).
- What happens when the `SyncStrategy` processes a very large queue (thousands of pending items)? The strategy should batch transmissions to avoid overwhelming the remote, with configurable batch sizes.
- What happens when the app is killed mid-sync? Partially synced batches should be resumable; the sync status tracking must be atomic per-item.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The framework MUST provide a `--sync` flag that, when passed to `zfa make`, generates a local-first, offline-first repository implementation with automatic background synchronization to the remote data source.

- **FR-001a**: The sync feature MUST be implemented as a standalone `SyncPlugin` (following the same architecture as `CachePlugin`), registered in the plugin registry with its own `SyncCommand` for CLI invocation (e.g., `zfa sync <Entity>`). The plugin MUST expose capabilities for enabling sync on an entity and for managing sync status (e.g., `zfa sync enable <Entity>`, `zfa sync status <Entity>`). The `--sync` flag on `zfa make` triggers the same plugin internally, exactly as `--cache` triggers `CachePlugin`.

- **FR-002**: When sync is enabled, the generated repository MUST write all data operations (create, update, delete) to the local data source first and return immediately, without blocking on network availability.

- **FR-003**: When sync is enabled, the generated repository MUST read all data (get, getList) from the local data source only. Reads MUST NOT make network calls.

- **FR-004**: The sync plugin MUST generate a `SyncStrategy` component that is injected into the sync-enabled repository (analogous to `CachePolicy` for cached repositories). The strategy defines how pending local changes are detected, transmitted to the remote data source, and how sync status is updated upon success.

- **FR-005**: The `SyncStrategy` MUST retry failed transmissions with exponential backoff, up to a configurable maximum number of attempts, before marking the record as permanently failed.

- **FR-006**: The `SyncStrategy` MUST track sync status per-record in a separate sync metadata store, NOT as a field on the domain entity. This keeps the domain entity pure (no infrastructure concerns). The metadata store maps entity identifier → sync status (`pending`, `syncing`, `synced`, `failed`). The entity identifier is the entity's `id` field if one exists, or the entity's `hashCode` as fallback (all Zorphy entities generate a `hashCode` via `Object.hash(...)`). The sync metadata store MUST be generated automatically when sync is enabled.

- **FR-007**: The framework MUST generate a `Sync<Entity>UseCase` that allows the application layer to manually trigger a sync operation for a specific entity.

- **FR-008**: The framework MUST register the `SyncStrategy`, sync metadata store, sync use case, and all related components in the dependency injection container automatically when `--di` is also enabled.

- **FR-009**: The sync plugin MUST be compatible with the existing `--cache` plugin's local data source (Hive-based) infrastructure, reusing the same Hive box and adapter registration patterns.

- **FR-010**: When `--sync --bidirectional` is specified, the `SyncStrategy` MUST also pull data from the remote data source and merge it into local storage during sync operations.

- **FR-011**: The `SyncStrategy` MUST support configurable conflict resolution strategies for bidirectional sync. The default strategy MUST be "remote-wins" (server-authoritative).

- **FR-012**: The `SyncStrategy` MUST support batch processing of pending records to avoid overwhelming the remote data source, with a configurable batch size (default: 50 records per batch).

- **FR-013**: The generated sync infrastructure MUST follow Clean Architecture principles: sync domain logic in the domain layer (`SyncStrategy` interface, use cases), sync data logic in the data layer (`SyncStrategy` implementation, remote interaction), with proper dependency inversion throughout. The `SyncStrategy` is injected into the sync-enabled repository, exactly as `CachePolicy` is injected into cached repositories.

- **FR-014**: The sync plugin MUST generate tests for the sync-enabled repository and `SyncStrategy`, covering: push sync success, push sync failure with retry, read from local, and bidirectional pull sync.

- **FR-015**: The framework MUST allow enabling sync on any existing entity by re-running `zfa make <Entity> --sync` with append behavior, adding sync status tracking and sync use case without destroying existing code.

- **FR-016**: The `SyncStrategy` MUST log all sync operations (attempts, successes, failures) for observability and debugging.

- **FR-017**: The `SyncStrategy` MUST be cancelable — a sync operation in progress can be cancelled via a `CancelToken`, consistent with Zuraffa's existing UseCase cancellation patterns.

- **FR-018**: The framework MUST generate a `SyncStatus` enum with at least: `pending`, `syncing`, `synced`, `failed`. This enum MUST NOT be added to the entity's field list — it is used exclusively by the separate sync metadata store. The domain entity remains pure.

- **FR-019**: When a record is deleted locally, the repository MUST hard-delete the record from the local data source immediately AND record a tombstone in the sync metadata store (with `deletedAt` timestamp). The `SyncStrategy` detects tombstoned metadata entries, sends a remote delete, and removes the metadata entry upon success. No soft-delete flag is stored in the local data box.

### Key Entities _(include if feature involves data)_

- **SyncStrategy**: A domain-level interface defining the contract for how local changes are synchronized to a remote data source. Injected into the sync-enabled repository (analogous to `CachePolicy` for cached repositories). Contains methods like `syncPending(CancelToken?)`, `pullRemote(CancelToken?)`, `getPendingCount()`, and `getSyncStatus(id)`. The implementation lives in the data layer and coordinates between local data source, remote data source, and sync metadata store. Different implementations provide different sync behaviors (e.g., `PushOnlySyncStrategy`, `BidirectionalSyncStrategy`).

- **SyncMetadataStore**: A separate persistence layer (Hive-based) that maps entity identifiers to their sync status. The key is the entity's `id` field if present, or the entity's `hashCode` as fallback. This keeps the domain entity pure — no `syncStatus` field pollutes the entity. The store tracks: `SyncStatus` (pending/syncing/synced/failed), `retryCount`, `lastAttemptAt`, `lastError`, and `deletedAt` (tombstone timestamp for tracking offline deletions).

- **SyncStatus**: An enum tracking the synchronization state of each record: `pending` (written locally, not yet pushed), `syncing` (currently being transmitted), `synced` (successfully transmitted), `failed` (transmission failed after max retries). Lives in the sync metadata store, NOT on the entity.

- **SyncQueue**: An internal concept representing the set of records with `pending` or `failed` status in the sync metadata store that need to be transmitted to the remote. The `SyncStrategy` queries the metadata store for records by status, then cross-references with the local data source to get the full entity data for transmission.

- **ConflictResolver**: A domain-level strategy interface for bidirectional sync that determines how to resolve conflicts when both local and remote have changes to the same record. Default implementation: remote-wins. Used by `BidirectionalSyncStrategy`.

- **SyncConfig**: Configuration for sync behavior: batch size, max retry count, backoff base delay, backoff max delay, sync direction (push-only vs. bidirectional), conflict resolution strategy.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A developer can generate a fully functional offline-first repository for any entity with a single command (`zfa make <Entity> --sync`), and the generated code compiles and passes all generated tests on the first run.

- **SC-002**: Write operations on a sync-enabled repository return in under 5 milliseconds (local-only write), regardless of network conditions — representing a 100x improvement over remote-first writes that typically take 200-2000ms.

- **SC-003**: Read operations on a sync-enabled repository return in under 5 milliseconds (local-only read), regardless of network conditions.

- **SC-004**: When the device is offline, 100% of write and read operations succeed without errors, and pending changes are automatically transmitted when connectivity is restored.

- **SC-005**: The generated `SyncStrategy` correctly transmits all pending records to the remote within 2 seconds of a sync trigger for typical workloads (under 100 pending records).

- **SC-006**: The sync plugin generates code that is fully compliant with Clean Architecture: domain layer has no knowledge of storage technology or network protocols, data layer contains all implementation details, and all dependencies point inward toward the domain.

- **SC-007**: The hack implementation (`SyncEngagementEventsUseCase`, `createRemote` method on repository, manual sync trigger in `InitializeConfigsUseCase`) is fully replaced by the generated sync infrastructure, with zero manual sync code remaining in the application.

- **SC-008**: A developer can combine `--sync` with other Zuraffa flags (`--with=vpc`, `--state`, `--di`, `--test`, `--cache`) without conflicts, and all generated code integrates correctly.

## Assumptions

- The existing local data source infrastructure (Hive-based, with box management and adapter registration) is the foundation for local-first persistence. The sync plugin builds on top of this, not replacing it.

- The existing `CachePolicy` concept (daily, restart, TTL) is a read-cache concept and is distinct from sync status tracking. Sync status is per-record and permanent (until synced); cache validity is time-based and ephemeral. Both can coexist on the same entity if both `--cache` and `--sync` are enabled.

- The remote data source interface already defines CRUD methods (`create`, `get`, `getList`, `update`, `delete`) that the `SyncStrategy` can call. The `SyncStrategy` does not define new remote methods; it orchestrates existing ones.

- Network connectivity detection is the application's responsibility (e.g., via `connectivity_plus` or a custom service). The sync plugin provides the `SyncStrategy`; the app decides when to trigger it. The plugin MAY generate a connectivity-aware sync trigger helper, but the core strategy is trigger-agnostic.

- Conflict resolution for bidirectional sync defaults to "remote-wins" (server-authoritative), which is the safest default for most applications. Custom conflict resolution is an extension point for advanced use cases.

- The sync status is tracked in a separate metadata store (Hive box), NOT as a field on the domain entity. This keeps the domain entity pure per Clean Architecture principles. The metadata store maps entity identifier → sync status. The identifier is the entity's `id` field if present, or the entity's `hashCode` as fallback (all Zorphy entities generate a `hashCode`). Existing entities that gain sync capability do NOT need any field added to the entity itself — only the separate metadata store is created.

- Retry with exponential backoff uses a base delay of 1 second and a max delay of 60 seconds, with a maximum of 5 retry attempts. These are configurable via `SyncConfig`.

- The sync plugin is designed for eventual consistency, not real-time sync. There is an inherent delay between a local write and the remote being updated. This delay is acceptable for the offline-first use case.
