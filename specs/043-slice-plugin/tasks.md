# Tasks: Slice Plugin — Context-Isolated Codebase Extraction

**Input**: Design documents from `/specs/043-slice-plugin/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] [BehaviorIDs] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[U#]/[A#]**: Behavior id from `specs/043-slice-plugin/tdd/test-list.md`. **Tests are MANDATORY and test-first**: a behavior's test task must be written and observed failing (red) before its implementation task starts; the failure is recorded in `specs/043-slice-plugin/tdd/cycle-log.md`. Each phase ends with one acceptance-gate task per acceptance criterion — the phase closes only when that outer-loop test is green.
- Include exact file paths in descriptions

## Path Conventions

- **Plugin source**: `lib/src/plugins/slice/`
- **Tests**: `test/plugins/slice/`
- **Plugin registration**: `lib/src/cli/plugin_loader.dart` and `lib/src/generator/code_generator.dart`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Plugin scaffold, registration, and CLI command shell

- [x] T001 Create plugin directory structure with all subdirectories per plan.md in lib/src/plugins/slice/ (engine/, models/, generators/, merger/, verifier/, exporter/, runner/, capabilities/)
- [x] T002 Create `SlicePlugin` class extending `ZuraffaPlugin` and implementing `CliAwarePlugin` in lib/src/plugins/slice/slice_plugin.dart — declare id `'slice'`, name, version, empty capabilities list, and `createCommand()` returning `SliceCommand`
- [x] T003 [U65] Create `SliceCommand` shell with subcommand dispatch (cut, merge, list, inspect, verify, run, export, import) using `ArgParser.allowAnything()` pattern from `BoneCommand` in lib/src/plugins/slice/slice_command.dart
- [x] T004 Register `SlicePlugin()` in `PluginLoader._plugins()` in lib/src/cli/plugin_loader.dart
- [x] T005 Register `SlicePlugin()` in `CodeGenerator` constructor in lib/src/generator/code_generator.dart

**Checkpoint**: `zfa slice` command is recognized and prints help/usage. No subcommands work yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that ALL user stories depend on — models, package resolver, and the graph traversal engine

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Models (no dedicated unit tests — exercised via T025 round-trip and T024 walker tests)

- [x] T006 [P] Create `SliceDepth` enum (view, presentation, feature, full) in lib/src/plugins/slice/models/slice_depth.dart
- [x] T007 [P] Create `FileOwnership` enum (owned, shared) in lib/src/plugins/slice/models/slice_file.dart
- [x] T008 [P] Create `SliceFile` model class with fields: relativePath, ownership, hashAtCut, layer in lib/src/plugins/slice/models/slice_file.dart
- [x] T009 [P] Create `SliceBoundary` model class with fields: typeName, interfaceFile, diRegistrationFile, mockStrategy in lib/src/plugins/slice/models/slice_boundary.dart
- [x] T010 [P] Create `SliceExportFormat` enum (tarGz, github) in lib/src/plugins/slice/models/slice_manifest.dart
- [x] T012 [P] Create `FileGraphNode` model class with fields: filePath, imports, diTypes, companions in lib/src/plugins/slice/models/file_graph.dart
- [x] T013 [U20] Create `FileGraph` model class with nodes map, packageName, projectRoot, and methods: `buildFromEntries()`, `getTransitiveClosure()`, `getBoundaries()` — stub implementations in lib/src/plugins/slice/models/file_graph.dart

### Tests (write FIRST — observe each failing before its implementation task)

- [x] T025 [P] [U1] [U2] [U3] Create unit test for `SliceManifest` YAML round-trip serialization in test/plugins/slice/models/slice_manifest_test.dart
- [x] T020 [P] [U4] [U5] [U6] [U7] [U8] Create unit test for `PackageResolver` with fixture `package_config.json` in test/plugins/slice/engine/package_resolver_test.dart
- [x] T021 [P] [U9] [U10] [U11] [U12] Create unit test for `ServiceLocatorAnalyzer` with fixture presenter source containing `getIt<T>()` calls in test/plugins/slice/engine/service_locator_analyzer_test.dart
- [x] T022 [P] [U13] [U14] [U15] [U16] Create unit test for `BarrelResolver` with fixture barrel file re-exporting multiple files in test/plugins/slice/engine/barrel_resolver_test.dart
- [x] T023 [P] [U17] [U18] [U19] Create unit test for `CompanionDetector` verifying `.g.dart` and `.freezed.dart` discovery in test/plugins/slice/engine/companion_detector_test.dart
- [x] T024 [U20] [U21] [U22] Create unit test for `ImportGraphWalker` with a multi-file fixture project testing depth boundaries and cycle detection in test/plugins/slice/engine/import_graph_walker_test.dart

### Implementation

- [x] T011 [U1] [U2] Create `SliceManifest` model class with fields: name, createdAt, depth, entries, projectRoot, packageName, branch, exportedTo, files, boundaries — include `toYaml()` and `fromYaml()` serialization in lib/src/plugins/slice/models/slice_manifest.dart
- [x] T019 [U1] [U2] [U3] Create `ManifestWriter` with `write(SliceManifest, String directory)` and `read(String directory)` methods for YAML serialization/deserialization in lib/src/plugins/slice/generators/manifest_writer.dart
- [x] T014 [U4] [U5] [U6] [U7] [U8] Create `PackageResolver` that reads `.dart_tool/package_config.json` and resolves `package:<name>/...` URIs to filesystem paths in lib/src/plugins/slice/engine/package_resolver.dart
- [x] T016 [U9] [U10] [U11] [U12] Create `ServiceLocatorAnalyzer` using `RecursiveAstVisitor` to extract `getIt<T>()` type arguments from a parsed `CompilationUnit` in lib/src/plugins/slice/engine/service_locator_analyzer.dart
- [x] T017 [U13] [U14] [U15] [U16] Create `BarrelResolver` that parses barrel files (`index.dart`), extracts export directives, and returns only the re-exported files matching a set of needed types in lib/src/plugins/slice/engine/barrel_resolver.dart
- [x] T015 [U17] [U18] [U19] Create `CompanionDetector` that finds `.g.dart` and `.freezed.dart` companion files for a given source file path in lib/src/plugins/slice/engine/companion_detector.dart
- [x] T018 [U20] [U21] [U22] Create `ImportGraphWalker` that performs transitive import resolution with boundary detection — uses `FileParser`, `AstHelper.extractImports()`, `PackageResolver`, `BarrelResolver`, `ServiceLocatorAnalyzer`, and `CompanionDetector` to build a `FileGraph` from entry points at a given `SliceDepth` in lib/src/plugins/slice/engine/import_graph_walker.dart

**Checkpoint**: Foundation ready — the graph traversal engine can trace dependencies from any entry point, resolve `package:` URIs, handle barrel files, detect `getIt<T>()` service-locator calls, and find companion files. All models serialize cleanly. User story implementation can now begin.

---

## Phase 3: User Story 1 — Cut a Feature Slice (Priority: P1) 🎯 MVP

**Goal**: Extract a runnable, self-contained slice from one or more entry points into a sandbox directory with mock DI wiring

**Independent Test**: Run `zfa slice cut product_feature --entry product` on a fixture project and verify the sandbox contains exactly the expected file set, compiles, and has a working `main_slice.dart`

### Tests for User Story 1 (write FIRST — observe each failing before its implementation task)

- [x] T033 [US1] [A1] [A2] [A3] [A4] Create test fixture project with minimal Zuraffa structure (entity, usecase, repository, presenter with getIt<T>(), view, controller, state, DI files) in test/fixtures/slice_test_project/
- [x] T077 [P] [US1] [U27] [U28] Create unit test for the ownership classifier — page-directory files classify owned, entities/domain/shared-widget/core files classify shared — in test/plugins/slice/engine/ownership_classifier_test.dart
- [ ] T078 [P] [US1] [U29] [U30] Create unit test for `MockStubGenerator` — boundary mock generation and existing-mock reuse — in test/plugins/slice/generators/mock_stub_generator_test.dart
- [ ] T079 [P] [US1] [U32] [U33] Create unit test for `SandboxBootstrapper` — `main_slice.dart` content and minimal `slice_di.dart` registrations — in test/plugins/slice/generators/sandbox_bootstrapper_test.dart
- [ ] T080 [P] [US1] [U35] [U36] Create unit test for `AgentReadmeGenerator` — `SLICE.md` ownership markings, run command, boundary list — in test/plugins/slice/generators/agent_readme_generator_test.dart
- [ ] T085 [P] [US1] [U65] [U66] Create unit test for `SliceCommand` argument validation — unknown subcommand usage error, `cut` without `--entry` usage error — in test/plugins/slice/slice_command_test.dart
- [ ] T034 [US1] [A1] [A2] [A3] [A4] Create integration test: cut a slice from fixture project, verify sandbox structure, file count, ownership classification, manifest contents, and `main_slice.dart` content in test/plugins/slice/slice_cut_integration_test.dart

### Implementation for User Story 1

- [x] T026 [US1] [U27] [U28] Create file ownership classifier that marks files as owned (in page directory) or shared (entities, domain interfaces, shared widgets) based on path conventions in lib/src/plugins/slice/engine/ownership_classifier.dart
- [ ] T027 [US1] [U29] [U30] Create `MockStubGenerator` that generates lightweight mock implementations for boundary interfaces (abstract classes at the traversal edge) in lib/src/plugins/slice/generators/mock_stub_generator.dart
- [ ] T028 [US1] [U32] [U33] Create `SandboxBootstrapper` that generates `main_slice.dart` entry point — imports the root view, sets up mock DI via `setupSliceDependencies()`, wraps in `MaterialApp` — and generates `slice_di.dart` with only needed registrations in lib/src/plugins/slice/generators/sandbox_bootstrapper.dart
- [ ] T029 [US1] [U35] [U36] Create `AgentReadmeGenerator` that generates `SLICE.md` listing: slice contents, modifiable files (owned), read-only files (shared), run command, boundary interfaces with their mock implementations in lib/src/plugins/slice/generators/agent_readme_generator.dart
- [ ] T030 [US1] [A1] [A2] [A3] [A4] Create `CutSliceCapability` implementing `ZuraffaCapability` with `plan()` (dry-run file list) and `execute()` (actually copy files, generate sandbox artifacts, write manifest) in lib/src/plugins/slice/capabilities/cut_slice_capability.dart
- [ ] T031 [US1] [A1] [A2] [A3] [A4] [U66] Implement the `cut` subcommand in `SliceCommand` — parse `--entry` (repeatable), `--depth` (default: feature), `--verify` flag, slice name from positional arg — delegate to `CutSliceCapability.execute()` in lib/src/plugins/slice/slice_command.dart
- [ ] T032 [US1] [A1] [A2] [A3] [A4] Wire `CutSliceCapability` into `SlicePlugin.capabilities` list in lib/src/plugins/slice/slice_plugin.dart

### Acceptance gates for User Story 1 (phase closes only when each is green)

- [ ] T087 [US1] [A1] Acceptance gate US1-S1: `zfa slice cut product_feature --entry product` on the fixture produces exactly the expected files (view/controller/presenter/state/usecases/entities/mock DI/`main_slice.dart`) and nothing unrelated — test in test/plugins/slice/slice_cut_integration_test.dart
- [ ] T088 [US1] [A2] Acceptance gate US1-S2: shared widgets are included in the sandbox and classified `shared` in slice.yaml — test in test/plugins/slice/slice_cut_integration_test.dart
- [ ] T089 [US1] [A3] Acceptance gate US1-S3: `getIt<T>()`-resolved usecases and their DI registration files are included — test in test/plugins/slice/slice_cut_integration_test.dart
- [ ] T090 [US1] [A4] Acceptance gate US1-S4: a barrel (`index.dart`) import pulls in only the re-exported symbols the slice references — test in test/plugins/slice/slice_cut_integration_test.dart

**Checkpoint**: `zfa slice cut` produces a runnable sandbox. This is the MVP — a developer can extract a feature slice and hand the sandbox to an agent.

---

## Phase 4: User Story 2 — Merge Agent Changes Back (Priority: P1)

**Goal**: Merge modified files from a sandbox back into the main project using hash-based conflict detection (extended per 2026-08-29 user decision: agent-created and agent-deleted files are merged too — see tdd/test-list.md)

**Independent Test**: Cut a slice, modify a file in the sandbox, run merge, verify the main project reflects the modification and the sandbox is cleaned up

### Tests for User Story 2 (write FIRST — observe each failing before its implementation task)

- [ ] T040 [US2] [U37] [U38] [U39] [U40] Create unit test for `ConflictDetector` covering: not-modified (skip), agent-modified-only (safe_copy), both-modified (conflict), shared-file warning in test/plugins/slice/merger/conflict_detector_test.dart
- [ ] T081 [P] [US2] [U41] [U42] [U43] [U44] [U67] [U68] Create unit test for `SliceMerger` — safe-copy only, shared-file confirmation, conflict preservation, no-change cleanup, agent-created file copy-back, agent-deleted file removal — in test/plugins/slice/merger/slice_merger_test.dart
- [ ] T041 [US2] [A5] [A6] [A7] [A8] Create integration test: cut → modify file → merge → verify main project updated and sandbox deleted in test/plugins/slice/slice_merge_integration_test.dart

### Implementation for User Story 2

- [ ] T035 [US2] [U37] [U38] [U39] [U40] Create `ConflictDetector` implementing 3-way hash comparison (sandbox_hash vs cut_hash vs main_hash) returning: skip, safe_copy, or conflict per file in lib/src/plugins/slice/merger/conflict_detector.dart
- [ ] T036 [US2] [U41] [U42] [U43] [U44] [U67] [U68] Create `SliceMerger` that iterates manifest files, runs `ConflictDetector` on each, copies safe files back to project, warns on shared-file modifications, reports conflicts, merges agent-created files to their mirrored paths and removes agent-deleted files, and cleans up sandbox on success in lib/src/plugins/slice/merger/slice_merger.dart
- [ ] T037 [US2] [A5] [A6] [A7] [A8] Create `MergeSliceCapability` implementing `ZuraffaCapability` with `plan()` (preview which files would be copied/conflicted) and `execute()` (perform merge) in lib/src/plugins/slice/capabilities/merge_slice_capability.dart
- [ ] T038 [US2] [A5] [A6] [A7] [A8] Implement the `merge` subcommand in `SliceCommand` — parse slice name, delegate to `MergeSliceCapability.execute()` in lib/src/plugins/slice/slice_command.dart
- [ ] T039 [US2] [A5] [A6] [A7] [A8] Wire `MergeSliceCapability` into `SlicePlugin.capabilities` list in lib/src/plugins/slice/slice_plugin.dart

### Acceptance gates for User Story 2 (phase closes only when each is green)

- [ ] T091 [US2] [A5] Acceptance gate US2-S1: merge copies back only the agent-modified file to its original path, touching nothing else — test in test/plugins/slice/slice_merge_integration_test.dart
- [ ] T092 [US2] [A6] Acceptance gate US2-S2: merge of a modified `shared` file warns and requires confirmation before overwriting — test in test/plugins/slice/slice_merge_integration_test.dart
- [ ] T093 [US2] [A7] Acceptance gate US2-S3: a file changed in both sandbox and main project since the cut is reported as a conflict, never silently overwritten — test in test/plugins/slice/slice_merge_integration_test.dart
- [ ] T094 [US2] [A8] Acceptance gate US2-S4: merge with no modifications reports "no changes to merge" and deletes the slice directory — test in test/plugins/slice/slice_merge_integration_test.dart

**Checkpoint**: The full cut → work → merge round-trip works. Combined with US1, this completes the core value proposition.

---

## Phase 5: User Story 3 — List and Inspect Active Slices (Priority: P2)

**Goal**: Provide operational visibility into active slices — names, entry points, file counts, modification status

**Independent Test**: Create two slices, run `zfa slice list` and `zfa slice inspect <name>`, verify output matches actual sandbox contents

### Tests for User Story 3 (write FIRST — observe each failing before its implementation task)

- [ ] T044 [US3] [A9] [A10] Create test: cut two slices from fixture project, verify `list` output includes both, verify `inspect` correctly identifies modified files in test/plugins/slice/slice_list_inspect_test.dart

### Implementation for User Story 3

- [ ] T042 [US3] [A9] Implement `list` subcommand in `SliceCommand` — scan `.zuraffa/slices/` for directories containing `slice.yaml`, read each manifest, display table of name, entries, created date, file count, depth in lib/src/plugins/slice/slice_command.dart
- [ ] T043 [US3] [A10] Implement `inspect` subcommand in `SliceCommand` — read manifest for named slice, compute current hashes for all files, display detailed table with file path, ownership, layer, and modified-since-cut status in lib/src/plugins/slice/slice_command.dart

### Acceptance gates for User Story 3 (phase closes only when each is green)

- [ ] T095 [US3] [A9] Acceptance gate US3-S1: `zfa slice list` shows both active slices with name, entry points, creation date, and file count — test in test/plugins/slice/slice_list_inspect_test.dart
- [ ] T096 [US3] [A10] Acceptance gate US3-S2: `zfa slice inspect` shows every file with ownership classification and modified-since-cut status — test in test/plugins/slice/slice_list_inspect_test.dart

**Checkpoint**: Developer can manage multiple concurrent slices with full visibility.

---

## Phase 6: User Story 4 — Multi-Entry Slice (Priority: P2)

**Goal**: Support multiple entry points per slice, unioning their dependency graphs with deduplication

**Independent Test**: Cut a slice with `--entry profile --entry preferences`, verify the sandbox contains both pages and their combined dependencies without duplication

### Tests for User Story 4 (write FIRST — observe each failing before its implementation task)

- [ ] T048 [US4] [A11] [A12] [U26] Create test: cut slice with two entries sharing a common usecase, verify usecase appears once in manifest, both pages present in sandbox in test/plugins/slice/slice_multi_entry_test.dart

### Implementation for User Story 4

- [ ] T045 [US4] [U26] Extend `ImportGraphWalker.buildFromEntries()` to accept `List<String>` entries, union their traversal results into a single `FileGraph` with deduplicated nodes in lib/src/plugins/slice/engine/import_graph_walker.dart
- [ ] T046 [US4] [A11] [A12] Update `CutSliceCapability` to handle multiple `--entry` flags and pass all entries to the graph walker in lib/src/plugins/slice/capabilities/cut_slice_capability.dart
- [ ] T047 [US4] [U34] Update `SandboxBootstrapper` to generate `main_slice.dart` with multiple root views (e.g., a `TabBarView` or simple `Navigator` with routes for each entry) in lib/src/plugins/slice/generators/sandbox_bootstrapper.dart

### Acceptance gates for User Story 4 (phase closes only when each is green)

- [ ] T097 [US4] [A11] Acceptance gate US4-S1: a two-entry cut contains both pages' dependency trees with shared dependencies included exactly once — test in test/plugins/slice/slice_multi_entry_test.dart
- [ ] T098 [US4] [A12] Acceptance gate US4-S2: a usecase shared by both entries appears once in the manifest with one DI registration — test in test/plugins/slice/slice_multi_entry_test.dart

**Checkpoint**: Cross-screen features can be sliced as a single unit.

---

## Phase 7: User Story 5 — Configurable Extraction Depth (Priority: P3)

**Goal**: Support depth levels (view, presentation, feature, full) controlling how deep the graph traversal goes

**Independent Test**: Cut the same entry at depths `view`, `feature`, and `full`, verify each includes the correct layer set

### Tests for User Story 5 (write FIRST — observe each failing before its implementation task)

- [ ] T052 [US5] [U23] [U24] [U25] [U31] Create test: cut at each depth level, verify file counts and layer inclusion match expected sets in test/plugins/slice/slice_depth_test.dart

### Implementation for User Story 5

- [ ] T049 [US5] [U23] [U24] [U25] Implement depth-based boundary rules in `ImportGraphWalker` — define which directory patterns (`presentation/`, `domain/`, `data/`) are included at each `SliceDepth` level, stop traversal at the boundary layer in lib/src/plugins/slice/engine/import_graph_walker.dart
- [ ] T050 [US5] [U31] Update `MockStubGenerator` to generate mocks appropriate for each depth — at `view` depth, mock the presenter; at `feature` depth, mock the repository; at `full` depth, no mocks needed in lib/src/plugins/slice/generators/mock_stub_generator.dart
- [ ] T051 [US5] [A13] [A14] [A15] Update `SandboxBootstrapper` to adjust DI setup based on depth — fewer mocks at deeper depths, real implementations at `full` in lib/src/plugins/slice/generators/sandbox_bootstrapper.dart

### Acceptance gates for User Story 5 (phase closes only when each is green)

- [ ] T099 [US5] [A13] Acceptance gate US5-S1: `--depth view` includes view/controller/state and no presenter, usecases, or entities — test in test/plugins/slice/slice_depth_test.dart
- [ ] T100 [US5] [A14] Acceptance gate US5-S2: `--depth feature` (default) adds presenter/usecases/domain interfaces/entities but no data implementations — test in test/plugins/slice/slice_depth_test.dart
- [ ] T101 [US5] [A15] Acceptance gate US5-S3: `--depth full` additionally includes repository implementations, datasources, and providers — test in test/plugins/slice/slice_depth_test.dart

**Checkpoint**: Developers can control context size by choosing the appropriate depth for their task type.

---

## Phase 8: User Story 6 — Verify Slice Integrity (Priority: P1)

**Goal**: Two-tier verification — fast import resolution check and optional `dart analyze` on the sandbox

**Independent Test**: Cut a slice, run verify (should pass), delete a file from sandbox, run verify again (should report the dangling import)

### Tests for User Story 6 (write FIRST — observe each failing before its implementation task)

- [ ] T058 [US6] [U45] [U46] [U47] Create unit test for `ImportVerifier` with fixture files: one with all imports resolved, one with a dangling import in test/plugins/slice/verifier/import_verifier_test.dart
- [ ] T082 [P] [US6] [U48] [U49] [U50] Create unit test for `AnalyzeRunner` — clean pass, structured error capture, missing-toolchain environment error — in test/plugins/slice/verifier/analyze_runner_test.dart

### Implementation for User Story 6

- [ ] T053 [US6] [U45] [U46] [U47] Create `ImportVerifier` that parses every `.dart` file in the sandbox, extracts imports, and checks each resolves to: another file in sandbox, a package in pubspec.yaml, or a dart:/flutter: SDK library — reports unresolved imports with file and line number in lib/src/plugins/slice/verifier/import_verifier.dart
- [ ] T054 [US6] [U48] [U49] [U50] Create `AnalyzeRunner` that executes `dart analyze` (or `flutter analyze` if Flutter project) on the sandbox directory, captures stdout/stderr, and returns structured pass/fail result in lib/src/plugins/slice/verifier/analyze_runner.dart
- [ ] T055 [US6] [A16] [A17] [A18] Create `VerifySliceCapability` implementing `ZuraffaCapability` — `plan()` lists files to check, `execute()` runs import verification (and optionally analyze), returns pass/fail with details in lib/src/plugins/slice/capabilities/verify_slice_capability.dart
- [ ] T056 [US6] [A16] [A17] [A18] Implement the `verify` subcommand in `SliceCommand` — parse slice name, `--analyze` flag, delegate to `VerifySliceCapability.execute()` in lib/src/plugins/slice/slice_command.dart
- [ ] T057 [US6] [A19] Integrate `--verify` flag into `cut` subcommand — after sandbox creation, run `ImportVerifier`; if it fails, delete sandbox and report error in lib/src/plugins/slice/slice_command.dart

### Acceptance gates for User Story 6 (phase closes only when each is green)

- [ ] T102 [US6] [A16] Acceptance gate US6-S1: `zfa slice verify` on a complete slice reports all imports resolved — test in test/plugins/slice/slice_verify_integration_test.dart
- [ ] T103 [US6] [A17] Acceptance gate US6-S2: verify on a slice missing a file reports exactly which files have unresolved imports and which import paths are broken — test in test/plugins/slice/slice_verify_integration_test.dart
- [ ] T104 [US6] [A18] Acceptance gate US6-S3: `verify --analyze` runs `dart analyze` on the sandbox and reports compilation errors — test in test/plugins/slice/slice_verify_integration_test.dart
- [ ] T105 [US6] [A19] Acceptance gate US6-S4: `zfa slice cut --verify` auto-verifies after extraction and fails the extraction when the slice is incomplete — test in test/plugins/slice/slice_verify_integration_test.dart

**Checkpoint**: Developers can verify a slice is complete before handing it to an agent. The `--verify` flag on `cut` provides fail-fast quality gating.

---

## Phase 9: User Story 7 — Run Slice as Standalone App (Priority: P2)

**Goal**: Launch the slice as a standalone Flutter app via a convenience command

**Independent Test**: Cut a verified slice, run `zfa slice run <name>`, verify Flutter launches with the slice's entry point

### Tests for User Story 7 (write FIRST — observe each failing before its implementation task)

- [ ] T061 [US7] [U51] [U52] [U53] Create test: verify `SliceRunner` constructs the correct `flutter run` command with the right `-t` path and passthrough args (mock `Process.run`) in test/plugins/slice/runner/slice_runner_test.dart

### Implementation for User Story 7

- [ ] T059 [US7] [U51] [U52] Create `SliceRunner` that resolves the slice manifest, extracts the `main_slice.dart` path, and executes `flutter run -t <path>` in the project root, forwarding additional CLI args in lib/src/plugins/slice/runner/slice_runner.dart
- [ ] T060 [US7] [U53] [A20] [A21] [A22] Implement the `run` subcommand in `SliceCommand` — parse slice name and passthrough flags (e.g., `--device`, `-d`), run `ImportVerifier` first, then delegate to `SliceRunner` in lib/src/plugins/slice/slice_command.dart

### Acceptance gates for User Story 7 (phase closes only when each is green)

- [ ] T106 [US7] [A20] Acceptance gate US7-S1: `zfa slice run <name>` launches `flutter run -t .zuraffa/slices/<name>/main_slice.dart` from the project root — test in test/plugins/slice/runner/slice_runner_test.dart (asserts constructed command via fake process seam; the repo test env has no Flutter SDK)
- [ ] T107 [US7] [A21] Acceptance gate US7-S2: `run` on an unverified slice verifies first and aborts without launching when verification fails — test in test/plugins/slice/runner/slice_runner_test.dart
- [ ] T108 [US7] [A22] Acceptance gate US7-S3: extra flags (e.g. `--device chrome`) pass through to the underlying `flutter run` — test in test/plugins/slice/runner/slice_runner_test.dart

**Checkpoint**: `zfa slice run profile_feature -d chrome` launches the slice — no need to remember the nested entry point path.

---

## Phase 10: User Story 8 — Export Slice for Cloud Agent Handoff (Priority: P2)

**Goal**: Export a slice as a `.tar.gz` archive or a GitHub repository for cloud agent consumption, and import agent changes back

**Independent Test**: Cut a slice, export as tar.gz, extract to a clean directory, verify `flutter analyze` passes. For GitHub: verify repo created with correct structure (via fake `gh` seam — the repo test env has no network).

### Tests for User Story 8 (write FIRST — observe each failing before its implementation task)

- [ ] T069 [US8] [U54] [U55] [U56] Create unit test for `PubspecFilter` verifying only used dependencies are kept, `flutter` always included in test/plugins/slice/exporter/pubspec_filter_test.dart
- [ ] T070 [US8] [U57] Create unit test for `TarballExporter` verifying archive contains expected files and filtered pubspec in test/plugins/slice/exporter/tarball_exporter_test.dart
- [ ] T083 [P] [US8] [U59] [U60] [U61] [U62] Create unit test for `GithubExporter` — repo create/push/README, `--repo` honored vs auto-name, `exportedTo` recorded, unauthenticated `gh` error — via a fake gh-process seam in test/plugins/slice/exporter/github_exporter_test.dart
- [ ] T084 [P] [US8] [U63] [U64] Create unit test for `SliceImporter` — pull-over-sandbox and missing-`exportedTo` error — in test/plugins/slice/exporter/slice_importer_test.dart
- [ ] T086 [P] [US8] [U58] Create unit test for the export verify-gate — export aborts when verification fails and no artifact is produced — in test/plugins/slice/capabilities/export_slice_capability_test.dart

### Implementation for User Story 8

- [ ] T062 [US8] [U54] [U55] [U56] Create `PubspecFilter` that reads the project's `pubspec.yaml`, scans all sliced `.dart` files for `package:` import URIs, extracts package names, and writes a filtered `pubspec.yaml` containing only used dependencies (plus `flutter` and `flutter_test` always) in lib/src/plugins/slice/exporter/pubspec_filter.dart
- [ ] T063 [US8] [U57] Create `TarballExporter` that copies the sandbox directory into a staging area, adds the filtered `pubspec.yaml`, and produces a `.tar.gz` archive using `dart:io` `gzip` + `tar` in lib/src/plugins/slice/exporter/tarball_exporter.dart
- [ ] T064 [US8] [U59] [U60] [U61] [U62] Create `GithubExporter` that creates a new private GitHub repository (via `gh` CLI or GitHub MCP tools), pushes sandbox contents as initial commit, uses `SLICE.md` as `README.md`, and stores the repo URL in `slice.yaml` `exportedTo` field in lib/src/plugins/slice/exporter/github_exporter.dart
- [ ] T065 [US8] [U63] [U64] Create `SliceImporter` that reads `exportedTo` URL from `slice.yaml`, clones/pulls the GitHub repo into a temp directory, copies contents over the local sandbox, ready for `zfa slice merge` in lib/src/plugins/slice/exporter/slice_importer.dart
- [ ] T066 [US8] [U58] [A23] [A24] [A25] [A26] Create `ExportSliceCapability` implementing `ZuraffaCapability` — accepts `format` (tarGz/github), optional `repo` name, runs verify first, delegates to `TarballExporter` or `GithubExporter` in lib/src/plugins/slice/capabilities/export_slice_capability.dart
- [ ] T067 [US8] [A23] [A24] [A25] [A26] Implement the `export` subcommand in `SliceCommand` — parse slice name, `--format` (tar.gz|github), `--repo` (optional), delegate to `ExportSliceCapability.execute()` in lib/src/plugins/slice/slice_command.dart
- [ ] T068 [US8] [A27] Implement the `import` subcommand in `SliceCommand` — parse slice name, `--from github` flag, delegate to `SliceImporter` in lib/src/plugins/slice/slice_command.dart

### Acceptance gates for User Story 8 (phase closes only when each is green)

- [ ] T109 [US8] [A23] Acceptance gate US8-S1: `export --format tar.gz` produces an archive with all sandbox files and a self-contained filtered pubspec.yaml — test in test/plugins/slice/slice_export_integration_test.dart
- [ ] T110 [US8] [A24] Acceptance gate US8-S2: `export --format github --repo <name>` creates/pushes a repo with SLICE.md as README and a working pubspec.yaml — test in test/plugins/slice/slice_export_integration_test.dart (fake `gh` seam)
- [ ] T111 [US8] [A25] Acceptance gate US8-S3: `export --format github` without `--repo` auto-generates a repo name from project and slice name — test in test/plugins/slice/slice_export_integration_test.dart
- [ ] T112 [US8] [A26] Acceptance gate US8-S4: export of an unverified slice runs verification first and aborts when it fails — test in test/plugins/slice/slice_export_integration_test.dart
- [ ] T113 [US8] [A27] Acceptance gate US8-S5: `zfa slice import --from github` pulls the repo contents back into the local sandbox, ready for `slice merge` — test in test/plugins/slice/slice_export_integration_test.dart

**Checkpoint**: `zfa slice export profile_feature --format github` creates a repo a cloud agent can clone. `zfa slice import profile_feature --from github` pulls changes back for merge.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T071 Add `configKey: 'sliceByDefault'` and config schema to `SlicePlugin` for `.zfa.json` integration in lib/src/plugins/slice/slice_plugin.dart
- [ ] T072 Add `--help` text and usage examples to each subcommand in `SliceCommand` in lib/src/plugins/slice/slice_command.dart
- [ ] T073 [P] Add verbose logging (gated by `--verbose` flag) throughout `ImportGraphWalker`, `CutSliceCapability`, and `SliceMerger` for debugging graph traversal
- [ ] T074 [P] Add progress reporting for long-running operations (graph traversal, file copy, archive creation) using Zuraffa's `ProgressReporter` pattern
- [ ] T075 [A1] [A5] Create end-to-end integration test: cut → verify → modify → merge full lifecycle on the fixture project in test/plugins/slice/slice_e2e_test.dart
- [ ] T076 Run quickstart.md validation scenarios against the completed plugin

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 Cut (Phase 3)**: Depends on Foundational — this is the MVP
- **US2 Merge (Phase 4)**: Depends on Foundational — can run in parallel with US1
- **US3 List/Inspect (Phase 5)**: Depends on Foundational — can run in parallel with US1/US2
- **US4 Multi-Entry (Phase 6)**: Depends on US1 (extends its graph walker and bootstrapper)
- **US5 Depth (Phase 7)**: Depends on US1 (extends its graph walker and mock generator)
- **US6 Verify (Phase 8)**: Depends on Foundational — can run in parallel with US1/US2/US3
- **US7 Run (Phase 9)**: Depends on US6 (verify runs before run)
- **US8 Export (Phase 10)**: Depends on US6 (verify runs before export)
- **Polish (Phase 11)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundational only — no other story dependencies. **This is the MVP.**
- **US2 (P1)**: Foundational only — independent of US1 (operates on existing sandboxes)
- **US3 (P2)**: Foundational only — independent (reads manifests, no graph traversal)
- **US4 (P2)**: Extends US1 — modifies `ImportGraphWalker` and `SandboxBootstrapper`
- **US5 (P3)**: Extends US1 — modifies `ImportGraphWalker` and `MockStubGenerator`
- **US6 (P1)**: Foundational only — independent (operates on sandbox files)
- **US7 (P2)**: Depends on US6 (runs verify before launch)
- **US8 (P2)**: Depends on US6 (runs verify before export)

### Within Each User Story

- Test tasks (observed failing) before their implementation tasks
- Models/enums before engine classes
- Engine classes before generators
- Generators before capabilities
- Capabilities before command wiring
- Command wiring before integration tests
- Acceptance-gate tasks close the phase (outer-loop test green)

### Parallel Opportunities

- T006–T010, T012: All model/enum files can be created in parallel
- T014–T017: PackageResolver, CompanionDetector, ServiceLocatorAnalyzer, BarrelResolver are independent engine components (each preceded by its test task T020–T023)
- T020–T023, T025: All unit tests for foundational components can run in parallel
- T077–T080, T085: All new US1 unit tests can run in parallel (after T033 fixture exists)
- US1, US2, US3, US6: Can all start simultaneously after Foundational phase
- T062–T065: All exporter components are independent files (preceded by tests T069, T070, T083, T084, T086)
- T071–T074: All polish tasks are independent

---

## Parallel Example: Foundational Phase

```
# Launch all model files together (T006–T010, T012):
Task: "Create SliceDepth enum in lib/src/plugins/slice/models/slice_depth.dart"
Task: "Create FileOwnership enum + SliceFile model in lib/src/plugins/slice/models/slice_file.dart"
Task: "Create SliceBoundary model in lib/src/plugins/slice/models/slice_boundary.dart"
Task: "Create SliceExportFormat enum in lib/src/plugins/slice/models/slice_manifest.dart"
Task: "Create FileGraphNode model in lib/src/plugins/slice/models/file_graph.dart"

# Launch all engine unit tests together FIRST (T020–T023, red), then implementations (T014–T017):
Task: "Create PackageResolver test in test/plugins/slice/engine/package_resolver_test.dart"
Task: "Create ServiceLocatorAnalyzer test in test/plugins/slice/engine/service_locator_analyzer_test.dart"
Task: "Create BarrelResolver test in test/plugins/slice/engine/barrel_resolver_test.dart"
Task: "Create CompanionDetector test in test/plugins/slice/engine/companion_detector_test.dart"
```

## Parallel Example: Post-Foundational

```
# After foundational is complete, start US1 + US2 + US3 + US6 in parallel:
Agent A: US1 (Cut) — T026–T034, T077–T080, T085, gates T087–T090
Agent B: US2 (Merge) — T035–T041, T081, gates T091–T094
Agent C: US3 (List/Inspect) — T042–T044, gates T095–T096
Agent D: US6 (Verify) — T053–T058, T082, gates T102–T105
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (T001–T005)
2. Complete Phase 2: Foundational (T006–T025)
3. Complete Phase 3: User Story 1 — Cut (T026–T034, T077–T080, T085, gates T087–T090)
4. **STOP and VALIDATE**: `zfa slice cut product_feature --entry product` on fixture project
5. The developer can now extract feature slices and hand sandboxes to agents manually

### Incremental Delivery

1. Setup + Foundational → Plugin recognized, engine works
2. Add US1 (Cut) → MVP: extract slices ✅
3. Add US2 (Merge) → Full round-trip: cut → work → merge ✅
4. Add US6 (Verify) → Quality gate: broken slices caught early ✅
5. Add US3 (List/Inspect) → Operational visibility ✅
6. Add US7 (Run) → One-command launch ✅
7. Add US8 (Export) → Cloud agent handoff ✅
8. Add US4 (Multi-Entry) → Cross-screen features ✅
9. Add US5 (Depth) → Fine-grained context control ✅
10. Polish → Logging, help text, config integration ✅

### Parallel Team Strategy

With multiple developers/agents:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Agent A: US1 (Cut) — the core extraction pipeline
   - Agent B: US2 (Merge) — the merge-back pipeline
   - Agent C: US6 (Verify) — the integrity checker
   - Agent D: US3 (List/Inspect) — the introspection commands
3. After US1 + US6 complete:
   - Agent E: US7 (Run) + US8 (Export) — both depend on verify
   - Agent F: US4 (Multi-Entry) + US5 (Depth) — both extend cut

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- [U#]/[A#] markers map tasks to behaviors in `tdd/test-list.md`; `/speckit.tdd.run` ticks a task only when its behavior ids are green
- Tests are mandatory, test-first, and must be observed failing before implementation (see `tdd/cycle-log.md` for red evidence)
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The fixture project (T033) is critical — it's the ground truth for all integration tests
- Merge scope was extended by user decision (2026-08-29): agent-created and agent-deleted sandbox files are merged, not just modified ones (U67/U68; FR-008 extension — bake into spec.md via `/speckit.clarify`)
- The test suite baseline is RED (8 pre-existing failures unrelated to this feature — see `tdd/cycle-log.md` baseline); do not start the loop until these are resolved or explicitly accepted
