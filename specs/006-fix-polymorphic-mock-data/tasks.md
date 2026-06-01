# Tasks: Fix Polymorphic Mock Data Generation

**Input**: Design documents from `specs/006-fix-polymorphic-mock-data/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Integration tests for polymorphic mock data generation are explicitly included per user request.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Source**: `lib/src/` at repository root
- **Unit tests**: `test/plugins/mock/`
- **Integration tests**: `test/integration/`
- **Fixtures**: `test/fixtures/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No project initialization needed — this is a bug fix to an existing codebase.

- [ ] T001 Verify all existing mock tests pass as baseline with `dart test test/plugins/mock/mock_builder_test.dart`

---

## Phase 2: Foundational — Core Polymorphic Detection Fix

**Purpose**: Fix `getPolymorphicSubtypes()` to detect sealed class hierarchies. This is the critical prerequisite that unblocks US1, US2, and US3.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T002 Implement `_detectSealedSubtypes()` method in `lib/src/utils/entity_analyzer.dart` using regex to find concrete subtypes via `sealed class` + `extends` patterns, excluding abstract/sealed subtypes
- [ ] T003 Update `getPolymorphicSubtypes()` in `lib/src/utils/entity_analyzer.dart` to call `_detectSealedSubtypes()` after the existing `@Zorphy` check, with deduplication via `Set<String>`
- [ ] T004 Update `getPolymorphicSubtypes()` in `lib/src/utils/entity_analyzer.dart` to use `DiscoveryEngine.findFileSync()` for file resolution instead of hardcoded path

**Checkpoint**: `getPolymorphicSubtypes()` now detects both `@Zorphy` and `sealed class` subtypes. Existing Zorphy tests must still pass.

---

## Phase 3: User Story 1 — Generate Mock Data for Sealed Class Entities (Priority: P1) 🎯 MVP

**Goal**: Sealed class entities like `CategoryConfig` with concrete subtypes produce valid mock data files for each subtype without hanging.

**Independent Test**: Create a temp directory with a minimal sealed class hierarchy (base + 2 concrete subtypes), run `MockBuilder.generate()`, verify mock data files are created for each concrete subtype and the sealed base class is NOT instantiated.

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T005 [P] [US1] Add unit test for sealed class with 2 concrete subtypes in `test/plugins/mock/mock_builder_test.dart` — create temp entity file with `sealed class CategoryConfig`, `PrimaryCategory extends CategoryConfig`, `SecondaryCategory extends CategoryConfig`, run `MockBuilder.generate()`, verify 2 mock data files produced
- [ ] T006 [P] [US1] Add unit test for sealed class with abstract intermediate subtype in `test/plugins/mock/mock_builder_test.dart` — create hierarchy with `sealed class Base`, `abstract class Middle extends Base`, `class Leaf extends Middle`, verify only `Leaf` gets mock data
- [ ] T007 [P] [US1] Add unit test for sealed class with no concrete subtypes (all abstract) in `test/plugins/mock/mock_builder_test.dart` — verify warning emitted, no mock data files for sealed base
- [ ] T008 [P] [US1] Create integration test `test/integration/polymorphic_mock_integration_test.dart` — test full `zfa mock data SealedEntity --force` CLI flow with a sealed class entity fixture, verify generated files compile and contain subtype instances

### Implementation for User Story 1

- [ ] T009 [US1] Verify `mock_builder.dart` line 77-89 handles polymorphic subtypes correctly for sealed classes — ensure subtypes flow into `generateNestedEntityMockFiles()` (should work via existing path if T002-T004 are correct)
- [ ] T010 [US1] Verify `mock_entity_graph_builder.dart` lines 36-71 handle sealed class subtypes — ensure each concrete subtype generates a mock data file via `generateMockDataFile(subtypeConfig)`
- [ ] T011 [US1] Verify `mock_value_builder.dart` `_entityValueExpr()` and `_generateListValueExpr()` use polymorphic subtypes for sealed classes — check that `refer('{subtype}MockData')` is used when subtypes exist
- [ ] T012 [US1] Create sealed class test fixture `test/fixtures/sealed_category_config.dart` — a complete sealed class hierarchy (1 base + 2 concrete subtypes) for use in integration tests

**Checkpoint**: Sealed class mock generation works end-to-end. Integration test passes.

---

## Phase 4: User Story 2 — Zorphy-Polymorphic Entities Still Work (Priority: P1)

**Goal**: Existing `@Zorphy(explicitSubTypes: [...])` mock data generation continues to work without regression after sealed class support is added.

**Independent Test**: Run existing mock builder tests for Zorphy polymorphic entities — all must pass unchanged.

### Tests for User Story 2 ⚠️

> **NOTE: These tests validate backward compatibility — they must PASS immediately after T002-T004, confirming no regression**

- [ ] T013 [P] [US2] Add unit test for `@Zorphy(explicitSubTypes: [SubA, SubB])` in `test/plugins/mock/mock_builder_test.dart` — verify both subtypes get mock data files
- [ ] T014 [P] [US2] Add unit test for entity using both `sealed class` and `@Zorphy` (mixed detection) in `test/plugins/mock/mock_builder_test.dart` — verify subtypes from both paths are detected, deduplicated, and mock files generated correctly
- [ ] T015 [US2] Run all existing mock builder tests: `dart test test/plugins/mock/mock_builder_test.dart` — confirm all 10 existing tests pass without modification

### Implementation for User Story 2

- [ ] T016 [US2] Add deduplication logic in `getPolymorphicSubtypes()` in `lib/src/utils/entity_analyzer.dart` — merge Zorphy and sealed subtypes in `Set<String>`, return as `List<String>`

**Checkpoint**: Both Zorphy and sealed class patterns work independently and together. All existing tests pass.

---

## Phase 5: User Story 3 — Clear Error Messages for Unresolvable Types (Priority: P2)

**Goal**: When entity files are missing or types cannot be resolved, the generator provides clear warnings/errors instead of hanging.

**Independent Test**: Run `zfa mock data NonExistentEntity` — must exit with error message in under 5 seconds.

### Tests for User Story 3 ⚠️

> **NOTE: Write these tests FIRST**

- [ ] T017 [P] [US3] Add unit test for missing entity file in `test/plugins/mock/mock_builder_test.dart` — verify `MockBuilder.generate()` with name `NonExistentEntity` exits cleanly with an error state instead of hanging
- [ ] T018 [P] [US3] Add unit test for unresolvable nested entity type in `test/plugins/mock/mock_builder_test.dart` — create entity A with field referencing entity B that doesn't exist, verify warning is logged and generation continues for entity A

### Implementation for User Story 3

- [ ] T019 [US3] Add try-catch around `analyzeEntity()` and `generateMockDataFile()` calls in `_collectAndGenerateNestedEntities()` in `lib/src/plugins/mock/builders/mock_entity_graph_builder.dart` — catch exceptions, log warning with type name, continue processing
- [ ] T020 [US3] Add error handling in `mock_builder.dart` `generate()` method — when `getPolymorphicSubtypes()` returns empty and entity file is not found, log clear error message instead of falling through to instantiation path

**Checkpoint**: All error paths produce clear messages. No hangs occur for any entity input.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validation, cleanup, and documentation

- [ ] T021 [P] Run all mock tests: `dart test test/plugins/mock/mock_builder_test.dart` — confirm all pass
- [ ] T022 [P] Run new integration test: `dart test test/integration/polymorphic_mock_integration_test.dart` — confirm all pass
- [ ] T023 Run full test suite: `dart test` — verify no regressions across entire project
- [ ] T024 [P] Run static analysis on modified files: `dart analyze lib/src/utils/entity_analyzer.dart lib/src/plugins/mock/builders/mock_entity_graph_builder.dart`
- [ ] T025 Validate quickstart.md scenario end-to-end — create a temp sealed class entity, run `zfa mock data <Entity> --force`, verify generated files compile

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (baseline check) — **BLOCKS all user stories**
- **User Story 1 (Phase 3)**: Depends on Phase 2 — can write tests (T005-T008) in parallel with Phase 2, but implementation (T009-T012) requires Phase 2 complete
- **User Story 2 (Phase 4)**: Depends on Phase 2 — primarily validation tasks, can run in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Phase 2 — can write tests (T017-T018) in parallel with US1/US2
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2 — No dependencies on other stories
- **User Story 2 (P1)**: Can start after Phase 2 — Independent from US1 (validation of existing behavior)
- **User Story 3 (P2)**: Can start after Phase 2 — Independent from US1/US2

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Core fix (Phase 2) before story-specific verification
- Story complete before moving to next priority

### Parallel Opportunities

- All Phase 3 test tasks (T005-T008) can run in parallel
- All Phase 4 test tasks (T013-T014) can run in parallel
- All Phase 5 test tasks (T017-T018) can run in parallel
- Phase 4 implementation (T016) can run in parallel with Phase 3 implementation (T009-T012)
- Once Phase 2 is complete, US1, US2, and US3 can proceed in parallel
- Phase 6 validation tasks (T021, T022, T024) can run in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 tests together (write first, expect failure):
Task: "T005 Add sealed class unit test in test/plugins/mock/mock_builder_test.dart"
Task: "T006 Add abstract intermediate subtype test in test/plugins/mock/mock_builder_test.dart"
Task: "T007 Add no concrete subtypes warning test in test/plugins/mock/mock_builder_test.dart"
Task: "T008 Create integration test in test/integration/polymorphic_mock_integration_test.dart"
```

## Parallel Example: Phase 2 + Test Writing

```bash
# Phase 2 (implementation) can run while Phase 3 tests are written:
Task: "T002 Implement _detectSealedSubtypes() in lib/src/utils/entity_analyzer.dart"
Task: "T003 Update getPolymorphicSubtypes() in lib/src/utils/entity_analyzer.dart"
Task: "T004 Update getPolymorphicSubtypes() to use DiscoveryEngine in lib/src/utils/entity_analyzer.dart"
# These tests can be written in parallel:
Task: "T005 Add sealed class unit test in test/plugins/mock/mock_builder_test.dart"
Task: "T006 Add abstract intermediate subtype test in test/plugins/mock/mock_builder_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Verify baseline tests pass
2. Complete Phase 2: Core fix — `_detectSealedSubtypes()` + `getPolymorphicSubtypes()` update
3. Complete Phase 3: Sealed class mock generation + tests
4. **STOP and VALIDATE**: Run `dart test test/plugins/mock/` and `dart test test/integration/polymorphic_mock_integration_test.dart`
5. Run `dart analyze` on modified files

### Incremental Delivery

1. Phase 1 + 2 → Foundational fix ready
2. Add US1 → Sealed classes work → Test → MVP!
3. Add US2 → Verify Zorphy regression-free → Test
4. Add US3 → Error handling → Test
5. Phase 6 → Full validation

### Parallel Team Strategy

With multiple developers:
1. Developer A: Phase 2 (core fix in `entity_analyzer.dart`)
2. Developer B: US1 tests + integration test (T005-T008, T012)
3. Developer C: US2 tests (T013-T015)
4. Once Phase 2 done: All converge on story implementations

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- T002-T004 are the critical path — all other tasks depend on them
- Integration test (T008) verifies the full end-to-end `zfa mock data` CLI flow for sealed entities
- Test fixture (T012) should be a real Dart file with a sealed class hierarchy for use in integration tests
- Commit after each logical group of tasks
- Stop at any checkpoint to validate story independently
