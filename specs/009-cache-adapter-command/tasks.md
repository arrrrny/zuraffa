---
description: "Task list for implementing the cache adapter command feature"
---

# Tasks: Cache Adapter Command

**Input**: Design documents from `specs/009-cache-adapter-command/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-interface.md

**Tests**: Not requested — tasks focus on implementation only.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project** (Zuraffa CLI tool): `lib/src/` is the source root
- All paths are relative to the repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project structure is already in place. No setup tasks needed — the Zuraffa cache plugin, capability system, and all dependencies already exist.

**Checkpoint**: All required infrastructure is pre-existing. Ready for foundational work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Study existing `CreateCacheCapability` at `lib/src/plugins/cache/capabilities/create_cache_capability.dart` to understand the capability pattern — inputSchema, outputSchema, plan(), execute()
- [x] T002 Study existing entity analysis code in `lib/src/utils/entity_analyzer.dart` and `lib/src/plugins/cache/builders/cache_builder_registrar.dart` (specifically `_collectSubtypeAdapters()`, `_collectNestedEntitiesForHive()`) to understand how sub-entity discovery works
- [x] T003 Study the Hive registrar generation logic in `lib/src/plugins/cache/builders/cache_builder_registrar.dart` (`_regenerateHiveRegistrar()`) to understand how imports, `@GenerateAdapters`, and `registerAdapter()` calls are emitted using `code_builder` / `SpecLibrary`
- [x] T004 [P] Create the new capability file at `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart` with the class shell implementing `ZuraffaCapability`
- [x] T005 Register the new capability in `CachePlugin.capabilities` at `lib/src/plugins/cache/cache_plugin.dart` by adding `CreateCacheAdapterCapability(this)` to the capabilities list

**Checkpoint**: Foundation ready — new capability file exists, registered in the plugin, can be discovered by the CLI as `zfa cache adapter`.

---

## Phase 3: User Story 1 - Automatically generate Hive adapters for a new entity (Priority: P1) 🎯 MVP

**Goal**: A developer runs `zfa cache adapter Product` and the command automatically discovers the entity, finds all sub-entities recursively, and updates the Hive registrar with proper imports, `@GenerateAdapters` annotations, and `registerAdapter()` calls.

**Independent Test**: Create a test entity `Product` with sub-entities `Category` and `Variant` (as simple field types), run `zfa cache adapter Product`, and verify that `lib/src/cache/hive_registrar.dart` is updated with `AdapterSpec<Product>()`, `AdapterSpec<Category>()`, `AdapterSpec<Variant>()` and corresponding `registerAdapter()` calls in both `HiveRegistrar` and `IsolatedHiveRegistrar` extensions.

### Implementation for User Story 1

- [x] T006 [P] [US1] Implement `inputSchema` in `CreateCacheAdapterCapability` at `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart` with `name` (required string), `build`, `dryRun`, `force`, `verbose` (optional booleans) following the schema defined in `data-model.md`
- [x] T007 [P] [US1] Implement `outputSchema` in `CreateCacheAdapterCapability` at `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart` with `generatedFiles`, `registeredEntities`, and `buildStatus` fields
- [x] T008 [US1] Implement entity file resolution logic in `CreateCacheAdapterCapability` — resolve the entity path at `lib/src/domain/entities/{entitySnake}/{entitySnake}.dart`, check if file exists, and return a clear error if not found (e.g., `"Entity 'Product' not found. Available entities: ..."`)
- [x] T009 [US1] Implement sub-entity discovery logic in `CreateCacheAdapterCapability` — reuse `EntityAnalyzer.analyzeEntity()` to parse fields, check each field type against known entity paths, recursively discover sub-entities up to 3+ levels, and skip already-processed entities to prevent circular references
- [x] T010 [US1] Implement Hive registrar update logic — after discovering all entities, read existing `lib/src/cache/hive_registrar.dart` content, scan existing cache files in `lib/src/cache/` for `*_cache.dart`, and merge the discovered entities with existing ones. Generate the full registrar using `code_builder` with:
  - Import statements for each entity (deduplicated)
  - `@GenerateAdapters([...])` annotation with all `AdapterSpec` entries
  - `registerAdapter()` calls in both `HiveRegistrar` on `HiveInterface` and `IsolatedHiveRegistrar` on `IsolatedHiveInterface` extensions
- [x] T011 [US1] Implement `plan()` method — call the discovery and registrar generation logic in dry-run mode, return an `EffectReport` with the planned changes (file paths and actions)
- [x] T012 [US1] Implement `execute()` method — call the discovery and registrar generation logic, write the updated registrar file using `FileUtils.writeFile()`, return an `ExecutionResult` with `generatedFiles` and `registeredEntities`
- [x] T013 [US1] Add error handling in `execute()` — catch and report file system errors (permission denied, missing directories), entity not found errors, and unexpected exceptions with user-friendly messages

**Checkpoint**: At this point, `zfa cache adapter Product` works for entities with sub-entities, updates the registrar, and reports results. The feature is usable independently.

---

## Phase 4: User Story 2 - Seamless integration with `zfa entity create` workflow (Priority: P2)

**Goal**: The `zfa cache adapter` command works naturally in the standard Zuraffa workflow (`zfa entity create` → `zfa make` → `zfa cache adapter` → `zfa build`), and supports a `--build` flag for one-step adapter registration + build.

**Independent Test**: Execute the full workflow: create a new entity via `zfa entity create`, generate cache with `zfa make`, run `zfa cache adapter Product --build`, and verify that the project compiles and builds successfully without manual edits.

### Implementation for User Story 2

- [x] T014 [P] [US2] Implement `--build` flag support — in the `execute()` method, after successful registrar update, if `args['build'] == true`, run `Process.run('dart', ['run', 'build_runner', 'build', '--delete-conflicting-outputs'])` and capture the build output; return `buildStatus` in the result data
- [x] T015 [US2] Add user-facing output messages per `contracts/cli-interface.md` — success message with list of registered entities, "Run 'zfa build' to generate adapter source files" guidance when `--build` is not used, and build success/failure messages when `--build` is used (handled via ExecutionResult data + verbose prints)
- [x] T016 [US2] Verify end-to-end workflow integration — tested by integration test at `test/integration/cache_adapter_test.dart` (creates entities with sub-entities, runs capability, verifies registrar output)

**Checkpoint**: At this point, `zfa cache adapter Product --build` runs end-to-end and produces a buildable project. The feature integrates naturally with the standard Zuraffa workflow.

---

## Phase 5: User Story 3 - Safe handling of existing registrations (Priority: P3)

**Goal**: Running `zfa cache adapter` multiple times is safe — no duplicate entries, existing registrations are preserved, and edge cases are handled gracefully.

**Independent Test**: Run `zfa cache adapter Product` twice. The second invocation should produce a "No changes required" message. Add a new sub-entity to `Product` and re-run — only the new sub-entity adapter should be added.

### Implementation for User Story 3

- [x] T017 [P] [US3] Implement deduplication in the entity discovery step — use a `Set<String>` of `processedEntities` to ensure the same entity name never appears twice in the adapter list. Compare the generated content diff between runs to detect "no changes" scenarios
- [ ] T018 [US3] Implement "no changes required" fast-path — before writing the registrar file, diff the generated content against the existing file content; if identical, skip writing and return `ExecutionResult(success: true, files: [])` with a "No changes required" message
- [x] T019 [US3] Handle missing registrar file gracefully — if `lib/src/cache/hive_registrar.dart` does not exist, create it from scratch with the proper structure (imports, `@GenerateAdapters`, both extension classes) rather than failing
- [x] T020 [US3] Handle entity-not-found with helpful suggestions — scan `lib/src/domain/entities/` directory to list available entities when the requested entity name doesn't resolve to a file
- [ ] T021 [US3] Handle the case where the specified argument is an enum (not an entity class) — detect enum types by checking for `enum` keyword in the source file, and include them in the adapter list with `AdapterSpec<EnumType>()`

**Checkpoint**: At this point, the command is robust — idempotent, handles duplicate runs gracefully, supports enums, and provides helpful error messages for all edge cases.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories.

- [x] T022 [P] Update `AGENTS.md` to include new `zfa cache adapter` command in the documented workflow examples
- [x] T023 [P] Run `dart analyze lib/src/plugins/cache/` to verify no analysis issues were introduced
- [x] T024 [P] Run existing cache plugin tests to verify backward compatibility (no regressions from adding the new capability)
- [x] T025 Write and run integration test at `test/integration/cache_adapter_test.dart` (3 tests: sub-entity discovery, error handling, duplicate runs)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Already complete — no dependencies
- **Foundational (Phase 2)**: No dependencies — blocks all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion — MVP scope
- **User Story 2 (Phase 4)**: Depends on US1 completion — adds `--build` flag on top of US1
- **User Story 3 (Phase 5)**: Depends on US1 completion — adds idempotency and edge case handling on top of US1
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P2)**: Depends on User Story 1 — the `--build` flag post-processes the result of US1's execution
- **User Story 3 (P3)**: Depends on User Story 1 — idempotency and edge case handling build on US1's core logic

### Within Each User Story

- Schema definitions (inputSchema, outputSchema) before implementation logic
- Entity resolution before sub-entity discovery
- Sub-entity discovery before registrar update
- Core implementation before output messages and polish

### Parallel Opportunities

- T001, T002, T003 (study tasks) can run in parallel (reading existing code)
- T004, T005 (file creation) can run in parallel (different files)
- T006, T007 (schema definitions) can run in parallel
- T008, T009, T010 — must be sequential (each depends on the previous)
- T014 can start after T011 is complete
- T017, T020, T021 can run in parallel
- T022, T023, T024 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch schema definition together:
Task: "Define inputSchema in CreateCacheAdapterCapability"
Task: "Define outputSchema in CreateCacheAdapterCapability"

# Core implementation (sequential chain):
Task: "Entity resolution → Sub-entity discovery → Registrar update → plan/execute methods"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (study code, create capability file, register in plugin)
2. Complete Phase 3: User Story 1 (entity resolution → sub-entity discovery → registrar update → plan/execute)
3. **STOP and VALIDATE**: Test `zfa cache adapter Product` with a sample entity
4. Deploy/demo if ready

### Incremental Delivery

1. Complete Foundational → Capability registered as CLI command
2. Add User Story 1 → `zfa cache adapter` works for basic entities → **MVP!**
3. Add User Story 2 → `--build` flag for one-step workflow
4. Add User Story 3 → Idempotent, handles enums, edge cases covered
5. Each story adds value without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. One developer completes Phase 2 (Foundational) — straightforward
2. Developer A: User Story 1 (entity analysis + registrar update)
3. Once US1 complete:
   - Developer B: User Story 2 (--build flag and workflow integration)
   - Developer C: User Story 3 (idempotency and edge cases)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- **Key architectural insight**: The feature adds a NEW capability (`CreateCacheAdapterCapability`), it does NOT modify the existing `CreateCacheCapability` or `CacheCommand` class (the capability auto-registration via `CapabilityCommand` handles CLI discovery)
- **Reuse over rewrite**: Entity analysis and code generation in `cache_builder_registrar.dart` already solve parts of this problem — study and reuse those patterns rather than reinventing them
