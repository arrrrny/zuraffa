---

description: "Task list for Skeleton Plugin — Bare-Bones Feature Scaffold"
---

# Tasks: Skeleton Plugin — Bare-Bones Feature Scaffold

**Input**: Design documents from `/specs/020-skeleton-plugin-bones/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — this feature is delivered through the TDD extension
(`/skill:speckit-tdd-plan` will derive the behavior test list and enforce
test-first ordering for every behavior task).

**Organization**: Tasks are grouped by user story (US1–US4 from spec.md) so
each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Paths are repo-relative; plugin code lives in `lib/src/plugins/skeleton/`,
  tests in `test/plugins/skeleton/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependency and directory scaffolding for the new plugin

- [X] T001 Add `archive: ^4.0.0` to `dependencies` in `pubspec.yaml` and run `dart pub get` (needed for FR-006 tar.gz export; see research.md Decision 6)
- [X] T002 Create plugin directory structure `lib/src/plugins/skeleton/` with subdirs `builders/`, `generators/`, `models/` per plan.md structure decision

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core models and plugin registration that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Create `Bone`, `BoneManifest`, `BoneDependency`, `EntityStub`, `EntityField`, `LayerPlaceholder` immutable model classes with validation rules from data-model.md in `lib/src/plugins/skeleton/models/bone.dart`
- [X] T035 [P] [U1] [U2] [U3] [U4] Test: `DependencyGraph` topological ordering, empty-graph ordering, cycle error naming members, and self-loop cycle in `test/plugins/skeleton/dependency_graph_test.dart` (write FIRST, must FAIL before T004)
- [X] T004 [P] [U1] [U2] [U3] [U4] Create `DependencyGraph` model (nodes/edges, Kahn topological sort, `CycleException` naming cycle members) in `lib/src/plugins/skeleton/models/dependency_graph.dart`
- [X] T036 [P] [U5] [U6] [U7] [U8] Test: `SpecReader` entity extraction, empty-section behavior, sha256 spec_version, and slug derivation in `test/plugins/skeleton/spec_reader_test.dart` (write FIRST, must FAIL before T005)
- [X] T005 [U5] [U6] [U7] [U8] Create `SpecReader` that structurally parses a feature `spec.md` (entities from `## Key Entities` bold entries, feature slug from path, SHA-256 of file bytes via `crypto`) in `lib/src/plugins/skeleton/generators/spec_reader.dart`
- [X] T037 [U32] Test: `zfa bone --help` lists the `generate`, `export`, `validate` subcommands in `test/plugins/skeleton/bone_command_test.dart` (write FIRST, must FAIL before T006)
- [X] T006 [U32] Create `SkeletonPlugin` (`FileGeneratorPlugin` + `CliAwarePlugin`, id `skeleton`) in `lib/src/plugins/skeleton/skeleton_plugin.dart` and the `zfa bone` command tree (`generate`/`export`/`validate` subcommands per contracts/cli.md) in `lib/src/plugins/skeleton/bone_command.dart`; register the plugin in `PluginLoader._plugins()` at `lib/src/cli/plugin_loader.dart`

**Checkpoint**: Plugin registered (`zfa bone --help` lists subcommands), models compile — user story implementation can now begin

---

## Phase 3: User Story 1 — Generate a standalone bone for a single feature (Priority: P1) 🎯 MVP

**Goal**: `zfa bone generate <feature-slug>` produces a self-contained bone:
manifest, entity stubs, layer placeholders, barrel entry point

**Independent Test**: Run the generator for a named feature and verify
`.zfa/bones/<slug>/` contains `bone.yaml`, entity stubs, `domain/` `data/`
`presentation/` placeholders, and `lib/<slug>.dart`; every import in the bone
resolves locally (quickstart.md Scenario 1)

### Tests for User Story 1 ⚠️ write FIRST, must FAIL before implementation

- [X] T007 [P] [US1] [U9] [U10] [U12] Test: `ManifestBuilder` renders `bone.yaml` matching the schema in contracts/bone-manifest.md (version, feature, spec_version `sha256:` format, entities, empty dependencies) in `test/plugins/skeleton/manifest_builder_test.dart`
- [X] T008 [P] [US1] [U18] [U19] Test: `BoneGenerator` emits the full bone file set (manifest, one stub per entity, barrel, 3 layer placeholders) and refuses when the spec declares no entities in `test/plugins/skeleton/bone_generator_test.dart`
- [X] T009 [P] [US1] [U21] [U22] Test: self-containment validation rejects a stub whose import is neither bone-local, `dart:*`, nor a declared dependency, and leaves no partial output in `test/plugins/skeleton/bone_generator_test.dart`

### Implementation for User Story 1

- [X] T010 [P] [US1] [U13] [U14] Implement `EntityStubBuilder` (Dart entity stub source via `code_builder`, formatted with `dart_style`) in `lib/src/plugins/skeleton/builders/entity_stub_builder.dart`
- [X] T011 [P] [US1] [U15] [U16] Implement `BoneScaffoldBuilder` (bone directory, layer placeholder READMEs, barrel entry point `lib/<snake>.dart`) in `lib/src/plugins/skeleton/builders/bone_scaffold_builder.dart`
- [X] T012 [P] [US1] [U9] [U10] [U11] [U12] Implement `ManifestBuilder` (YAML render of `BoneManifest`) in `lib/src/plugins/skeleton/builders/manifest_builder.dart`
- [X] T013 [US1] [U18] [U19] [U20] [U21] [U22] Implement `BoneGenerator` orchestration + self-containment import scanner (FR-005) in `lib/src/plugins/skeleton/generators/bone_generator.dart` (depends on T010–T012)
- [X] T014 [US1] [U26] [U31] Wire `zfa bone generate` (args per contracts/cli.md, output to `.zfa/bones/`, failure modes exit non-zero with no partial output) in `lib/src/plugins/skeleton/bone_command.dart`
- [X] T031 [US1] [A1] [A2] [A3] Acceptance test: drive `zfa bone generate` end to end and assert the bone's manifest/stubs/placeholders and self-containment in `test/plugins/skeleton/scenarios/sc_001_bone_generation_test.dart` — must be green before US1 is complete (A3 stays open — depends on US2 inter-bone dependency work)

**Checkpoint**: US1 complete — a bone generates for any spec with declared entities and passes self-containment validation

---

## Phase 4: User Story 2 — Declare inter-bone dependencies (Priority: P1)

**Goal**: Dependencies are auto-computed from entity cross-references across
feature specs; cycles and missing entities are hard errors

**Independent Test**: Two features where B references A's entity → B's
`bone.yaml` lists A with the shared entity; a circular pair fails with the
cycle members named; standalone bone gets `dependencies: []` (quickstart.md
Scenarios 2–3)

### Tests for User Story 2 ⚠️ write FIRST, must FAIL before implementation

- [X] T015 [P] [US2] [U23] Test: `DependencyResolver` builds a graph from cross-feature entity references and `topologicalSort()` returns a valid build order in `test/plugins/skeleton/dependency_resolver_test.dart`
- [X] T016 [P] [US2] [U24] [U25] Test: circular references throw `CycleException` naming the involved bones; a reference to an entity no feature defines throws a missing-dependency error; conflicting entity definitions are refused in `test/plugins/skeleton/dependency_resolver_test.dart`

### Implementation for User Story 2

- [X] T017 [US2] [U23] [U24] [U25] Implement `DependencyResolver` (scan `specs/*/spec.md` for entity declarations, match cross-references, build `DependencyGraph`, topological sort) in `lib/src/plugins/skeleton/generators/dependency_resolver.dart`
- [X] T018 [US2] [U20] [U22] Integrate the resolver into `BoneGenerator`: populate manifest `dependencies`, refuse output on cycle or missing entity (FR-003, FR-004, edge cases 1–2) in `lib/src/plugins/skeleton/generators/bone_generator.dart`
- [X] T032 [US2] [A4] [A5] [A6] Acceptance test: two-feature dependency declaration, cycle refusal, and empty-dependency bone end to end in `test/plugins/skeleton/scenarios/sc_002_dependency_graph_test.dart` — must be green before US2 is complete

**Checkpoint**: US1 AND US2 both work — multi-feature bone sets resolve in correct order, cycles refuse cleanly

---

## Phase 5: User Story 3 — Integrate with the existing SDD/TDD workflow (Priority: P2)

**Goal**: Bone generation composes with `specify` output and emits test stubs
the `tdd` plugin can expand

**Independent Test**: Generate from a specify-produced `spec.md` (default spec
resolution via `.specify/feature.json`); the bone's `test/` stubs are valid
Dart test scaffolds (quickstart.md Scenario 6)

### Tests for User Story 3 ⚠️ write FIRST, must FAIL before implementation

- [X] T019 [P] [US3] [U27] [U17] Test: `zfa bone generate` with no positional arg resolves the active feature from `.specify/feature.json`; the emitted `test/` stubs parse as valid `test`-package scaffolds in `test/plugins/skeleton/bone_command_test.dart`

### Implementation for User Story 3

- [X] T020 [US3] [U27] Add default spec resolution (`.specify/feature.json` → `specs/<slug>/spec.md`) and `--spec` override to the generate command in `lib/src/plugins/skeleton/bone_command.dart`
- [X] T021 [US3] [U17] Emit per-entity test stub files under the bone's `test/` directory (one `*_test.dart` scaffold per entity, importing the bone barrel) in `lib/src/plugins/skeleton/builders/bone_scaffold_builder.dart`
- [X] T022 [US3] [U33] Preserve xray annotations: if the source spec contains xray overlay markers, copy them verbatim into the bone manifest under an `xray:` key in `lib/src/plugins/skeleton/generators/spec_reader.dart` and `lib/src/plugins/skeleton/builders/manifest_builder.dart`
- [X] T033 [US3] [A7] [A8] [A9] Acceptance test: generate from a specify-produced spec with default resolution, run the bone's test stubs under `dart test`, and confirm xray markers survive in `test/plugins/skeleton/scenarios/sc_003_workflow_integration_test.dart` — must be green before US3 is complete

**Checkpoint**: US1–US3 work — define (specify) → scaffold (bone) → delegate flow is walkable end to end

---

## Phase 6: User Story 4 — Export a bone for external agent consumption (Priority: P2)

**Goal**: `zfa bone export` produces a single transferable `.tar.gz`; `zfa bone
validate` re-checks self-containment and spec staleness

**Independent Test**: Export a bone, list the tarball contents (all bone files
present); extract into a clean temp dir and validate; touch the source spec and
confirm validate reports staleness (quickstart.md Scenarios 4–5)

### Tests for User Story 4 ⚠️ write FIRST, must FAIL before implementation

- [X] T023 [P] [US4] [U28] [U29] Test: export writes a `.tar.gz` whose entries exactly match the bone directory contents, and fails non-zero when the bone was never generated in `test/plugins/skeleton/bone_command_test.dart`
- [X] T024 [P] [US4] [U30] Test: validate exits 0 for a clean bone and fails with a staleness message after the source spec changes (spec_version hash mismatch) in `test/plugins/skeleton/bone_command_test.dart`

### Implementation for User Story 4

- [X] T025 [US4] [U28] Implement tar.gz packaging via the `archive` package in `lib/src/plugins/skeleton/generators/bone_exporter.dart`
- [X] T026 [US4] [U29] [U30] [U31] Wire `zfa bone export` and `zfa bone validate` subcommands (arg handling and failure modes per contracts/cli.md) in `lib/src/plugins/skeleton/bone_command.dart`
- [X] T034 [US4] [A10] [A11] Acceptance test: export a bone, extract the artifact into a clean directory, and validate it standalone in `test/plugins/skeleton/scenarios/sc_004_export_test.dart` — must be green before US4 is complete

**Checkpoint**: All four stories functional — a bone can be generated, validated, exported, and consumed standalone

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Repo-wide hygiene for the feature

- [X] T027 [P] Run `dart analyze lib/src/plugins/skeleton test/plugins/skeleton` and fix all findings
- [X] T028 [P] Update `openwiki/` plugin docs if a plugin list exists there (check `openwiki/plugin-development.md`) with the new `skeleton` plugin
- [X] T029 Run quickstart.md Scenarios 1–6 end to end and record outcomes
- [X] T030 Run the fast suite `dart test` and confirm no regressions outside `test/plugins/skeleton/`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)** → **US2 (Phase 4)**: US2's resolver feeds the manifest US1's generator writes; sequential
- **US3 (Phase 5)**: Depends on US1 (generator + command exist)
- **US4 (Phase 6)**: Depends on US1 (a bone exists to export); independent of US2/US3
- **Polish (Phase 7)**: After all stories

### User Story Dependencies

- **US1 (P1)**: After Foundational. No story dependencies — the MVP.
- **US2 (P1)**: After US1 (extends `BoneGenerator` and the manifest).
- **US3 (P2)**: After US1 (extends command + scaffold builder).
- **US4 (P2)**: After US1; can run parallel with US2/US3 (different files except `bone_command.dart`, shared with US3 — sequence US3 → US4 for that file).

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD extension enforced)
- Builders before the generator that composes them
- Generator before command wiring

### Parallel Opportunities

- T003 + T004 (models, different files) in parallel
- T007 + T008 + T009 (US1 tests, two files — T008/T009 share a file, so T007 ∥ T008 then T009)
- T010 + T011 + T012 (US1 builders, different files) in parallel
- T015 + T016 share `dependency_resolver_test.dart` — sequential
- T023 + T024 share `bone_command_test.dart` — sequential
- T027 + T028 (polish) in parallel

---

## Parallel Example: User Story 1

```bash
# After Foundational completes, launch US1 builders together:
Task: "Implement EntityStubBuilder in lib/src/plugins/skeleton/builders/entity_stub_builder.dart"
Task: "Implement BoneScaffoldBuilder in lib/src/plugins/skeleton/builders/bone_scaffold_builder.dart"
Task: "Implement ManifestBuilder in lib/src/plugins/skeleton/builders/manifest_builder.dart"
# Then sequentially: BoneGenerator (T013) → command wiring (T014)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup → Phase 2 Foundational
2. Phase 3 US1 → **STOP and VALIDATE**: quickstart.md Scenario 1 passes
3. A standalone, self-contained bone generates — the core value is delivered

### Incremental Delivery

1. Setup + Foundational → plugin registered, models compile
2. + US1 → bone generation works (MVP)
3. + US2 → dependency graphs + cycle safety
4. + US3 → specify/tdd workflow integration
5. + US4 → export/validate for delegate handoff
6. Each story adds value without breaking previous stories

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [USn] label maps each story-phase task to spec.md user stories
- Test tasks are driven by `/skill:speckit-tdd-run`; behavior evidence lands in `specs/020-skeleton-plugin-bones/tdd/cycle-log.md`
- The repo's STOP-ON-ROADBLOCK rule (AGENTS.md) applies to `zfa` generation commands; this feature is hand-built plugin code inside the zuraffa package itself and does not use `zfa make`

---

## Phase 8: TDD remediation

**The feature is not done until the blocking findings (T038, T039) are cleared.**
Source: `tdd/verification.md` (verdict FAIL, 2026-08-29).

- [X] T038 [US4] [U37] Finding 1 (HIGH): prove the production import rejection can fail — test that `zfa bone validate` exits non-zero naming the file when a bone contains a broken relative import (inject one into a generated bone in a temp dir); drive any missing production behavior red-first in `test/plugins/skeleton/bone_command_test.dart` / `lib/src/plugins/skeleton/bone_command.dart`. Proven by: neutralizing the check makes the new test fail, restoring makes it pass
- [X] T039 [US1] [U38] Finding 2 (HIGH): pin the generated manifest's `spec_version` format end-to-end — test that a bone generated from a real spec has `spec_version` matching `sha256:` + 64 hex in the emitted `bone.yaml` in `test/plugins/skeleton/bone_generator_test.dart`. Proven by: the `'sha256:'` → `'sha1:'` mutant in `bone_generator.dart:86` makes it fail
- [X] T040 [US2] Finding 3 (MED): record red evidence for the 20 TEST_AFTER behaviors (U2–U4, U6–U8, U10–U12, U14, U16, U19, U22, U21, U31, A7–A11) — per behavior, revert/stub or mutate the minimal production code, run the behavior's test with `-n`, record the verbatim red in `tdd/cycle-log.md` (marked as an evidence-completion pass, not original ordering), restore exactly, re-run the scoped suite green
- [X] T041 [US1] Finding 4 (MED): make U14 assert the emitted stub's actual path (`lib/entities/cart_item.dart`) rather than only the class name in `test/plugins/skeleton/entity_stub_builder_test.dart:45-57`
- [X] T042 [US2] Finding 5 (MED): enforce the package:-import policy — `validate` rejects `package:` imports not covered by a declared dependency, and the A2/A11 acceptance scans assert the same instead of skipping, in `lib/src/plugins/skeleton/bone_command.dart:282`, `sc_001_bone_generation_test.dart:157-161`, `sc_004_export_test.dart:227`
- [X] T043 [US2] Finding 6 (MED): make A3 distinct from A4 (three-feature chain: C depends on B depends on A, asserting transitive order) or merge A3 into A4 with the drop recorded in the test list in `test/plugins/skeleton/scenarios/sc_002_dependency_graph_test.dart:81-108`
- [X] T044 [US3] Finding 7 (MED): strengthen A8 — verify emitted test stubs parse as valid Dart (parse or `dart analyze` the extracted bone) instead of string presence in `test/plugins/skeleton/scenarios/sc_003_workflow_integration_test.dart:148-164`
- [X] T045 [US1] Finding 8 (LOW): extract duplicated `captureOutput` / `copyFixture` helpers into `test/plugins/skeleton/helpers/` and update the 4+2 call sites
