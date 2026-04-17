# Tasks: Fix Zuraffa Code Generation Import and Type Emission

**Input**: Design documents from `/specs/004-fix-zuraffa-gen/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included per Constitution Principle IV (TDD is NON-NEGOTIABLE).

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Exact file paths included in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish test infrastructure and understand existing test patterns

- [x] T001 Read existing test files to understand test patterns: `test/plugins/provider/provider_plugin_test.dart`, `test/plugins/usecase/`, `test/plugins/repository/`
- [x] T002 [P] Create test helper for asserting generated imports are relative (no `package:` for project-local files) in `test/helpers/import_assertion_helper.dart`
- [x] T003 [P] Create test helper for asserting `UpdateParams` generic type consistency across layers in `test/helpers/generic_type_assertion_helper.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Fix the core `CommonPatterns.entityImports()` method that all generators depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Refactor `CommonPatterns.entityImports()` in `lib/src/core/builder/patterns/common_patterns.dart` to accept an output file path parameter and compute relative paths using `path.relative()` instead of `PackageUtils.getBaseImport()`
- [x] T005 Update all callers of `CommonPatterns.entityImports()` to pass the new output file path parameter: `entity_usecase_generator.dart`, `stream_usecase_generator.dart`, `presenter_plugin.dart`, `state_builder.dart`, `controller_plugin_utils.dart`, `interface_generator.dart`, `implementation_generator_append.dart`
- [x] T006 Remove or deprecate `PackageUtils.getBaseImport()` in `lib/src/utils/package_utils.dart` and update remaining callers in `lib/src/plugins/repository/generators/interface_generator.dart` and `lib/src/plugins/repository/generators/implementation_generator_append.dart`
- [x] T007 Update existing test in `test/plugins/provider/provider_plugin_test.dart:57` to expect relative imports instead of `package:app/` imports
- [x] T008 Run full test suite with `dart test` and verify all existing tests pass after foundational changes

**Checkpoint**: Foundation ready — `CommonPatterns.entityImports()` now produces relative paths, all callers updated, all tests pass

---

## Phase 3: User Story 1 - Relative Imports Instead of Package Imports (Priority: P1) 🎯 MVP

**Goal**: All generated files use relative imports for project-local references; zero `package:app/` or `package:<pkg>/` occurrences

**Independent Test**: Run `zfa generate Product --methods=get,getList,create,update,delete --data` in a project named `zik_zak` and verify all generated imports are relative

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Test that entity use case generator produces relative entity imports in `test/plugins/usecase/entity_usecase_generator_test.dart`
- [x] T010 [P] [US1] Test that stream use case generator produces relative entity imports in `test/plugins/usecase/stream_usecase_generator_test.dart`
- [x] T011 [P] [US1] Test that repository interface generator produces relative entity imports in `test/plugins/repository/interface_generator_test.dart`
- [x] T012 [P] [US1] Test that presenter plugin produces relative entity imports for custom use cases in `test/plugins/presenter/presenter_plugin_test.dart`
- [x] T013 [P] [US1] Test that state builder produces relative entity imports for custom use cases in `test/plugins/state/state_builder_test.dart`
- [x] T014 [P] [US1] Test that controller plugin produces relative entity imports in `test/plugins/controller/controller_plugin_test.dart`

### Implementation for User Story 1

- [x] T015 [P] [US1] Verify and fix entity use case generator imports in `lib/src/plugins/usecase/generators/entity_usecase_generator.dart` — entity imports should be relative after T004
- [x] T016 [P] [US1] Verify and fix stream use case generator imports in `lib/src/plugins/usecase/generators/stream_usecase_generator.dart` — entity imports should be relative after T004
- [x] T017 [P] [US1] Verify and fix repository interface generator imports in `lib/src/plugins/repository/generators/interface_generator.dart` — both entity imports (line 212, 232) and enum imports
- [x] T018 [P] [US1] Verify and fix implementation generator append imports in `lib/src/plugins/repository/generators/implementation_generator_append.dart` — entity and repository imports (lines 40, 49, 59)
- [x] T019 [P] [US1] Verify presenter plugin imports in `lib/src/plugins/presenter/presenter_plugin.dart` — custom use case entity imports use `CommonPatterns.entityImports()` (should be fixed by T004)
- [x] T020 [P] [US1] Verify state builder imports in `lib/src/plugins/state/builders/state_builder.dart` — custom use case entity imports
- [x] T021 [P] [US1] Verify controller plugin imports in `lib/src/plugins/controller/controller_plugin_utils.dart` — entity imports use `CommonPatterns.entityImports()`
- [x] T022 [US1] Run `dart test` and verify all US1 tests pass — zero `package:app/` in any generated output

**Checkpoint**: All generated files now use relative imports for project-local references. `package:zuraffa/zuraffa.dart` is the only package-style import remaining.

---

## Phase 4: User Story 3 - Correct Complex Generic Type Emission (Priority: P1)

**Goal**: `UpdateParams<IdType, DataType>` type is consistent across all layers, conditioned on `config.useZorphy`

**Independent Test**: Generate an entity with `--methods=update` (both with and without `--zorphy`) and verify consistent `UpdateParams` types in use case, repository interface, datasource, presenter, and DI files

> **NOTE**: US3 is P1 but ordered after US1 because it is fully independent (different files) and US1 is the more fundamental fix.

### Tests for User Story 3

- [x] T023 [P] [US3] Test that repository interface generator respects `useZorphy` flag for update method in `test/plugins/repository/interface_generator_test.dart`
- [x] T024 [P] [US3] Test that presenter plugin respects `useZorphy` flag for update method in `test/plugins/presenter/presenter_plugin_test.dart`
- [x] T025 [P] [US3] Test that service interface builder respects `useZorphy` flag for update method in `test/plugins/service/service_interface_builder_test.dart`
- [x] T026 [P] [US3] Test that provider builder respects `useZorphy` flag for update method in `test/plugins/provider/provider_builder_test.dart`
- [x] T027 [P] [US3] Test that mock provider builder respects `useZorphy` flag for update method in `test/plugins/mock/mock_provider_builder_test.dart`

### Implementation for User Story 3

- [x] T028 [P] [US3] Add `useZorphy` conditional to repository interface generator in `lib/src/plugins/repository/generators/interface_generator.dart:342` — change `final dataType = '${config.name}Patch';` to `final dataType = config.useZorphy ? '${config.name}Patch' : 'Partial<${config.name}>';`
- [x] T029 [P] [US3] Add `useZorphy` conditional to presenter plugin in `lib/src/plugins/presenter/presenter_plugin.dart:610` — change `final dataType = '${entityName}Patch';` to `final dataType = config.useZorphy ? '${entityName}Patch' : 'Partial<$entityName>';`
- [x] T030 [P] [US3] Add `useZorphy` conditional to service interface builder in `lib/src/plugins/service/builders/service_interface_builder.dart:165`
- [x] T031 [P] [US3] Add `useZorphy` conditional to provider builder in `lib/src/plugins/provider/builders/provider_builder.dart` at lines 376 and 491
- [x] T032 [P] [US3] Add `useZorphy` conditional to mock provider builder in `lib/src/plugins/mock/builders/mock_provider_builder.dart:740`
- [x] T033 [US3] Verify consistency of already-correct generators: `entity_usecase_generator.dart:195`, `implementation_generator_simple.dart:83`, `remote_generator.dart:250`, `local_generator_impl.dart:166`, `datasource/interface_generator.dart:182`, `test_builder_helpers.dart:93`
- [x] T034 [US3] Run `dart test` and verify all US3 tests pass — `UpdateParams` types are consistent across all layers for both `useZorphy=true` and `useZorphy=false`

**Checkpoint**: `UpdateParams<IdType, DataType>` is now consistently conditioned on `useZorphy` across all 11 generators

---

## Phase 5: User Story 2 - Correct Method Name Generation (Priority: P1)

**Goal**: Method names in use case `execute()` bodies match repository interface method signatures in 100% of generated files

**Independent Test**: Generate entities with various name patterns (`Product`, `ChatSession`, `User2FA`) and verify method name consistency across use case, repository, and DI layers

### Tests for User Story 2

- [x] T035 [P] [US2] Test method name consistency for simple entity (`Product`) across use case, repository interface, and DI in `test/plugins/usecase/entity_usecase_generator_test.dart`
- [x] T036 [P] [US2] Test method name consistency for compound entity (`ChatSession`) across all layers in `test/plugins/usecase/entity_usecase_generator_test.dart`
- [x] T037 [P] [US2] Test method name consistency for edge-case entity names (`User2FA`, `A`) in `test/plugins/usecase/entity_usecase_generator_test.dart`
- [x] T038 [P] [US2] Test custom use case method name via `--method` flag in `test/plugins/usecase/custom_usecase_generator_test.dart`

### Implementation for User Story 2

- [x] T039 [US2] Audit method name generation in `lib/src/plugins/usecase/generators/entity_usecase_generator.dart:109-348` — verify switch block maps correctly for all methods
- [x] T040 [US2] Audit method name generation in `lib/src/plugins/di/di_plugin.dart:1062-1098` — verify `_getUseCaseInfo()` mirrors use case generator naming
- [x] T041 [US2] Audit custom use case method name derivation in `lib/src/models/generator_config.dart:358-374` — verify `getRepoMethodName()` and `getServiceMethodName()`
- [x] T042 [US2] Fix any inconsistencies found during audit (specific files TBD based on findings)
- [x] T043 [US2] Run `dart test` and verify all US2 tests pass

**Checkpoint**: Method names are consistent across use case, repository, and DI layers for all entity name patterns

---

## Phase 6: User Story 4 - Consistent DI Relative Import Paths (Priority: P2)

**Goal**: DI registration files use correct relative paths for all project-local imports, verified by regression tests

**Independent Test**: Generate a complete feature with `--data --vpcs --di` and verify all DI imports resolve correctly

### Tests for User Story 4

- [x] T044 [P] [US4] Regression test: DI datasource imports use relative paths in `test/plugins/di/di_plugin_test.dart`
- [x] T045 [P] [US4] Regression test: DI repository imports use relative paths in `test/plugins/di/di_plugin_test.dart`
- [x] T046 [P] [US4] Regression test: DI use case imports use relative paths in `test/plugins/di/di_plugin_test.dart`
- [x] T047 [P] [US4] Regression test: DI cache imports use relative paths in `test/plugins/di/di_plugin_test.dart`

### Implementation for User Story 4

- [x] T048 [US4] Verify DI datasource import paths in `lib/src/plugins/di/di_plugin.dart:264-310` — confirm `../../data/datasources/...` paths are correct
- [x] T049 [US4] Verify DI repository import paths in `lib/src/plugins/di/di_plugin.dart:440-530` — confirm `../../domain/repositories/...` paths are correct
- [x] T050 [US4] Verify DI use case import paths in `lib/src/plugins/di/di_plugin.dart:900-1030` — confirm `../../domain/usecases/...` paths are correct
- [x] T051 [US4] Verify DI cache import paths in `lib/src/plugins/di/di_plugin.dart` — confirm `../../cache/...` paths are correct for all cache policy types
- [x] T052 [US4] Run `dart test` and verify all US4 tests pass

**Checkpoint**: DI import paths are verified correct and protected by regression tests

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: End-to-end validation and cleanup

- [x] T053 Run full end-to-end generation test: generate `ChatSession` with `--methods=get,getList,create,update,delete --data --vpcs --state --di` and verify zero `package:app/` or `package:zik_zak/` in output
- [x] T054 Run full end-to-end generation test with `--zorphy` disabled: verify `UpdateParams<..., Partial<...>>` is consistent across all layers
- [x] T055 Run full end-to-end generation test with `int` ID type: verify `UpdateParams<int, ...>` is consistent across all layers
- [x] T056 Run `dart test` full suite and verify all tests pass
- [x] T057 Run `dart analyze` and verify zero warnings
- [x] T058 Clean up: remove or deprecate `PackageUtils.getBaseImport()` if no longer called anywhere in `lib/src/utils/package_utils.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (Phase 2) — import path fix propagation
- **US3 (Phase 4)**: Depends on Foundational (Phase 2) — independent of US1 (different files)
- **US2 (Phase 5)**: Depends on Foundational (Phase 2) — audit benefits from import fixes being done
- **US4 (Phase 6)**: Depends on Foundational (Phase 2) — verification of DI paths
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — No dependencies on other stories
- **US2 (P1)**: Can start after Phase 2 — Independent but benefits from US1 being done for cleaner test output
- **US3 (P1)**: Can start after Phase 2 — Fully independent of US1 and US2 (different code paths)
- **US4 (P2)**: Can start after Phase 2 — DI paths already correct; this is verification + regression tests

### Parallel Opportunities

- All Phase 1 tasks (T001-T003) can run in parallel
- All US1 test tasks (T009-T014) can run in parallel
- All US1 verification tasks (T015-T021) can run in parallel
- All US3 implementation tasks (T028-T032) can run in parallel
- All US2 test tasks (T035-T038) can run in parallel
- All US4 test tasks (T044-T047) can run in parallel
- **US1 and US3 can run in parallel** (different files: imports vs generic types)
- **US2 and US4 can run in parallel** (different concerns: method names vs DI paths)

---

## Parallel Example: User Story 1 + User Story 3

```text
# After Phase 2 Foundational completes, these can run simultaneously:

# Stream A (US1 - Relative Imports):
Task T009: "Test entity use case generator relative imports"
Task T010: "Test stream use case generator relative imports"
Task T011: "Test repository interface generator relative imports"

# Stream B (US3 - useZorphy Consistency):
Task T023: "Test repository interface useZorphy flag"
Task T024: "Test presenter plugin useZorphy flag"
Task T025: "Test service interface builder useZorphy flag"

# Implementation also parallelizes:
Task T015: "Verify entity use case imports"        |  Task T028: "Fix interface_generator useZorphy"
Task T016: "Verify stream use case imports"         |  Task T029: "Fix presenter_plugin useZorphy"
Task T017: "Verify repository interface imports"    |  Task T030: "Fix service_interface_builder useZorphy"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T008) — **CRITICAL**
3. Complete Phase 3: User Story 1 (T009-T022)
4. **STOP and VALIDATE**: Generate code for `zik_zak` project, verify all imports are relative
5. Ship if ready — this alone fixes the most critical issue

### Incremental Delivery

1. Setup + Foundational → Core import fix ready
2. Add US1 → All generators produce relative imports (MVP!)
3. Add US3 → `UpdateParams` types consistent across all layers
4. Add US2 → Method name audit confirmed correct
5. Add US4 → DI regression tests protecting against future breakage
6. Polish → End-to-end validation complete

### Parallel Team Strategy

With multiple developers after Phase 2 completes:

- **Developer A**: US1 (T009-T022) — Import path propagation
- **Developer B**: US3 (T023-T034) — useZorphy consistency
- **Developer C**: US2 (T035-T043) — Method name audit
- **Developer D**: US4 (T044-T052) — DI regression tests

---

## Notes

- [P] tasks = different files, no dependencies
- **[Story]** label maps task to specific user story for traceability
- Each user story is independently completable and testable
- US1 and US3 touch different code paths and can be developed simultaneously
- The Foundational phase (T004-T005) is the highest-risk change — it modifies `CommonPatterns.entityImports()` which is called by 7+ generators
- T033 (verify already-correct generators) is a safety check, not a fix
- All `package:zuraffa/zuraffa.dart` imports remain unchanged — only project-local imports are affected
