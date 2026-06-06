# Tasks: Mock JSON Data Method

**Input**: Design documents from `/specs/008-mock-json-method/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Not explicitly requested — test tasks included as implementation-adjacent since plan.md lists test file paths. Marked optional.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Dart source**: `lib/src/` at repository root
- **Tests**: `test/` at repository root
- Paths follow existing project structure as defined in plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuration and model changes that all other tasks depend on

- [x] T001 [P] Add `generateMockJson` flag and `mockJsonDomain` field to GeneratorConfig in `lib/src/models/generator_config.dart`
- [x] T002 [P] Add `mockJsonByDefault` config key to ZfaConfig in `lib/src/config/zfa_config.dart`
- [x] T003 [P] Add `mock-json` option to MockPlugin configSchema in `lib/src/plugins/mock/mock_plugin.dart`
- [x] T004 [P] Create `JsonMockCapability` class implementing ZuraffaCapability with plan/execute methods in `lib/src/plugins/mock/capabilities/json_mock_capability.dart`

**Checkpoint**: Config models and capability class exist — downstream builders can reference them

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before any user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Add `generateMockValuesForJson()` method to MockValueBuilder that produces `List<Map<String, dynamic>>` (3 instances, same heuristics as existing `generateMockDataInstances`) in `lib/src/plugins/mock/builders/mock_value_builder.dart`
- [x] T006 Add `generateNestedEntityJsonNames()` method to MockEntityGraphBuilder that recursively discovers nested entity types and returns their names in `lib/src/plugins/mock/builders/mock_entity_graph_builder.dart`
- [x] T007 Add JSON path resolution utility methods (domain derivation, output path construction) in `lib/src/plugins/mock/builders/mock_json_builder.dart` (create file, add `domainForEntity()`, `jsonFilePathFor()`, `helperFilePathFor()` instance methods)

**Checkpoint**: Foundation ready — value generation can produce JSON data, entity graph walks nested types, path utilities available

---

## Phase 3: User Story 1 - Generate Mock Data as JSON Files (Priority: P1) 🎯 MVP

**Goal**: Developer invokes JSON mock generation for an entity and gets a valid JSON file + Dart helper that loads it via `fromJson`

**Independent Test**: Run `zfa mock json Product`, verify `data/mock_json/{domain}/product.mock.json` exists with valid JSON, verify `data/mock_json/{domain}/product_mock_json.dart` compiles and `loadProducts()` returns `List<Product>`

### Implementation for User Story 1

- [x] T008 [US1] Implement `MockJsonBuilder.generate()` method that orchestrates JSON data generation: calls MockValueBuilder for values, serializes to pretty-printed JSON, writes via FileUtils in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T009 [P] [US1] Implement `MockJsonHelperBuilder` that generates `{Entity}MockJson` Dart helper class with `load{Entity}s()`, `loadSample{Entity}()`, `loadSampleList()`, `loadEmptyList()` methods using `jsonDecode` and `{Entity}.fromJson()` in `lib/src/plugins/mock/builders/mock_json_helper_builder.dart`
- [x] T010 [US1] Wire `MockBuilder.generate()` to delegate to `mockJsonBuilder.generate()` when `config.generateMockJson` is true in `lib/src/plugins/mock/builders/mock_builder.dart`
- [x] T011 [US1] Register `JsonMockCapability` in MockPlugin.capabilities getter in `lib/src/plugins/mock/mock_plugin.dart`
- [x] T012 [US1] Add `JsonMockCommand` subcommand to MockCommand and handle `--json` flag in main mock command in `lib/src/commands/mock_command.dart`
- [x] T013 [US1] Handle nested entity recursion: when generating JSON for Order (containing List<OrderItem>), verify OrderItem gets its own JSON file + helper, and Order JSON includes nested object references in `lib/src/plugins/mock/builders/mock_json_builder.dart`

**Checkpoint**: At this point, `zfa mock json Product` generates JSON + helper, `fromJson` deserialization works, nested entities are handled

---

## Phase 4: User Story 2 - Clean Folder Convention for Mock JSON Data (Priority: P2)

**Goal**: Generated JSON files live in a predictable, domain-grouped folder structure separate from Dart mock code

**Independent Test**: Generate JSON mocks for entities in different domains, verify paths follow `data/mock_json/{domain}/{entity_snake}.mock.json` pattern, no collisions

### Implementation for User Story 2

- [x] T014 [US2] Implement domain auto-detection: derive domain from entity file path under `lib/src/domain/entities/{domain}/` in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T015 [P] [US2] Implement domain resolution priority: `--domain` flag > auto-detected domain > entity name as fallback in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T016 [US2] Create output directories on demand: ensure `data/mock_json/{domain}/` exists before writing files in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T017 [US2] Verify naming collision prevention: test that `Config` entities in `catalog` and `checkout` domains produce distinct paths in `lib/src/plugins/mock/builders/mock_json_builder.dart`

**Checkpoint**: Folder convention is consistent, domain-grouped, and prevents collisions

---

## Phase 5: User Story 3 - Seamless Swap of JSON Files During Prototyping (Priority: P3)

**Goal**: Developer can manually edit JSON files; regeneration doesn't overwrite edits; errors on corrupted files produce clear messages

**Independent Test**: Generate JSON mocks, manually edit the JSON file, re-run `zfa mock json Product` without `--force`, verify original edit is preserved, verify `--force` overwrites

### Implementation for User Story 3

- [x] T018 [US3] Implement generation metadata tracking: write `.mock.json.meta` companion file with content hash, timestamp, and field signature on first generation in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T019 [US3] Implement non-overwrite safety: before writing JSON file, check if it exists and compute hash comparison; skip overwrite if user-edited unless `--force` is provided in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T020 [US3] Implement field mismatch detection: compare current entity fields against stored signature in metadata; warn user if fields changed since last generation in `lib/src/plugins/mock/builders/mock_json_builder.dart`
- [x] T021 [US3] Implement error handling in Dart helper: catch missing file, malformed JSON, and `fromJson` failures with descriptive error messages including file path in `lib/src/plugins/mock/builders/mock_json_helper_builder.dart`
- [x] T022 [US3] Handle polymorphic discriminator: include `_type` field for sealed/polymorphic entities and generate switch-based deserialization in helper in `lib/src/plugins/mock/builders/mock_json_builder.dart` and `lib/src/plugins/mock/builders/mock_json_helper_builder.dart`

**Checkpoint**: User-edited JSONs survive regeneration, errors are clear, polymorphic types are supported

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Tests, edge cases, verification

- [x] T023 [P] Write unit tests for MockJsonBuilder (value generation, JSON output, path computation, metadata) in `test/plugins/mock/mock_json_builder_test.dart`
- [x] T024 [P] Write unit tests for MockJsonHelperBuilder (helper code generation, error handling, polymorphic switch) in `test/plugins/mock/mock_json_builder_test.dart`
- [x] T025 Write integration test: generate JSON mock for entity with all field types (String, int, double, bool, DateTime, enum, List, Map, nested entity), verify round-trip deserialization in `test/plugins/mock/mock_json_integration_test.dart`
- [x] T026 [P] Verify quickstart.md examples work end-to-end: run commands from quickstart, confirm output matches documented expectations
- [x] T027 Run `dart analyze` on all modified files and fix any issues
- [x] T028 Run existing mock plugin tests to verify no regressions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — MVP delivery
- **User Story 2 (Phase 4)**: Depends on US1 (builds on jsonBuilder path logic)
- **User Story 3 (Phase 5)**: Depends on US1 + US2 (builds on existing generation flow)
- **Polish (Phase 6)**: Depends on all user stories

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational — no dependencies on other stories
- **User Story 2 (P2)**: Depends on US1's MockJsonBuilder path logic being in place
- **User Story 3 (P3)**: Depends on US1 + US2 (metadata goes alongside JSON files, error handling in helper)

### Within Each User Story

- Builder implementation before CLI integration
- JSON file generation before Dart helper (helper references JSON path)
- Core path before nested entity recursion

### Parallel Opportunities

- T001, T002, T003, T004 can all run in parallel (Setup)
- T009 can run in parallel with T008 (different files, helper builder vs json builder)
- T015 can run in parallel with T014 (different concerns within same file)
- T023, T024 can run in parallel (different test files)
- T026, T027, T028 can run in parallel

---

## Parallel Example: User Story 1

```bash
# After Foundational phase, launch in parallel:
Task: "T008 Implement MockJsonBuilder.generate() in lib/src/plugins/mock/builders/mock_json_builder.dart"
Task: "T009 Implement MockJsonHelperBuilder in lib/src/plugins/mock/builders/mock_json_helper_builder.dart"
# T010 depends on both T008 and T009 completing
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T007)
3. Complete Phase 3: User Story 1 (T008-T013)
4. **STOP and VALIDATE**: Run `zfa mock json Product`, verify JSON + helper work
5. This is the MVP — JSON generation with fromJson support

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Generate JSON + helper → MVP deployable
3. Add User Story 2 → Clean folder convention → Organized, collision-free
4. Add User Story 3 → Non-overwrite safety, errors, polymorphic → Production-ready
5. Polish → Tests, analysis, regression check

### Parallel Team Strategy

With multiple developers:
1. All developers complete Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core generation)
   - Developer B: could start on US1 helper builder (T009) in parallel
3. US2 and US3 are sequential after US1 (extend same files)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- US2 and US3 both modify `mock_json_builder.dart` so they can't truly be parallel but are sequentially layered
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
