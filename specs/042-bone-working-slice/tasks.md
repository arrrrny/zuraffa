# Tasks: Bone Working Slice — minimal runnable Flutter app per feature with swappable DI

**Input**: Design documents from `/specs/042-bone-working-slice/` — [spec.md](./spec.md) · [plan.md](./plan.md)

## Phase 1: Models & parsing (MVP core)

- [x] T001 [P] [US1] Extend `SpecReadResult`/`SpecReader` with per-entity field parsing: indented
  `- name: Type` / `- name?: Type` lines under each `## Key Entities` bold entry; unknown type →
  parse error surfaced as `BoneGenerationError` naming entity + field + allowed types (FR-001,
  Edge: unsupported type).
- [x] T002 [P] [US1] Add `EntityField` nullability + `supportedTypes` validation to
  `models/bone.dart`; field-less entities remain legal (US1.AC4).
- [x] T003 [P] [US2] Add `DiChoice` model (mock | firebase | auto → resolved + source:
  flag | auto-detected | auto-fallback) to `models/bone.dart`.
- [x] T004 [P] [US1] Extend `Bone` model with `diChoice`, `includeDeps`, `flutter` fields and a
  separate `inlinedEntities` list (shared entities from dependency features).

## Phase 2: Real entity generation

- [x] T005 [P] [US1] Rewrite `EntityStubBuilder` → real entity emission: final fields, const
  constructor, `fromJson` (type-coercing), `toJson`, `copyWith`, `validate` (blank/missing required
  fields; nullable `?` fields skipped) (FR-001).
- [x] T006 [P] [US1] Entity emission for field-less entities: same shape with vacuous validation
  (US1.AC4).
- [x] T007 [P] [US1] Strip leading digit prefixes from slug-derived Dart identifiers (Edge:
  `042-…` slug) — shared `CaseNames` helper tested for `042-bone-working-slice`,
  `sample-feature`, `ProfilePage`.

## Phase 3: Domain / data / DI builders

- [x] T008 [P] [US1] `repository_builder.dart`: abstract `<E>Repository` (getById/getAll/save/
  delete), abstract `<E>DataSource` (same shape), `Data<E>Repository` coded against the data
  source (FR-002).
- [x] T009 [P] [US1] `usecase_builder.dart`: Get/Create/Update/Delete use cases per entity,
  repository via constructor injection, `call` method (FR-003).
- [x] T010 [P] [US1] `datasource_builder.dart`: `<E>MockDataSource` — in-memory store seeded with
  type-appropriate sample values, zero external services (FR-004, US6).
- [x] T011 [P] [US2] `datasource_builder.dart`: `<E>FirebaseDataSource` — Firestore REST over
  `dart:io HttpClient` (project id + API key credentials; missing-credentials `StateError`)
  (FR-004, US2.AC2, Edge: no credentials).
- [x] T012 [P] [US2] `injection_builder.dart`: self-contained DI container registering every
  repository, default backend from `DiChoice`, runtime `BoneBackend` selection, no external
  packages (FR-006).

## Phase 4: Tests inside the bone

- [x] T013 [P] [US6] `test/<entity>_test.dart` per own entity: fromJson round-trip, validation
  failures, copyWith — plain Dart, `dart:*` + bone-relative imports only (FR-012, US6.AC1).
- [x] T014 [P] [US6] `test/di_test.dart`: mock backend wired end-to-end through the DI container
  (getAll + save round-trip) (FR-012, US6.AC1).

## Phase 5: Flutter mode

- [x] T015 [P] [US3] `app_entry_builder.dart`: minimal `pubspec.yaml` (environment + flutter SDK
  deps only) and runnable `lib/main.dart` (build DI container → runApp → feature page) (FR-008,
  US3.AC1).
- [x] T016 [P] [US3] `presentation_builder.dart`: `<Feature>Page` real UI over the primary entity
  invoking ≥ 1 use case via the DI container (FR-005, US3.AC2).
- [x] T017 [P] [US3] `test/<feature>_page_test.dart` widget test using `flutter_test` (FR-012).

## Phase 6: DI resolution + CLI flags

- [x] T018 [P] [US2] `di_choice_resolver.dart`: resolve `--di auto` by scanning the working
  project's `pubspec.yaml`/`zfa.yaml` for firebase references; fallback mock (FR-009, US2.AC3/4).
- [x] T019 [US2] `bone_command.dart`: `--di` option (allowed values, default auto; invalid →
  usage error, exit non-zero, nothing generated) (FR-009, US2.AC5).
- [x] T020 [US3] `bone_command.dart`: `--flutter` flag toggling pubspec/main/page/widget-test
  emission (FR-008, US3.AC3).
- [x] T021 [US4] `bone_command.dart`: `--include-deps` flag → recursive transitive shared-entity
  inlining via existing `DependencyResolver`; cycles/duplicates still refuse (FR-010, US4).
- [x] T022 [US5] `bone_command.dart`: `--export` flag → `<feature>-<di>.tar.gz` after successful
  generation; no artifact on failure (FR-011, US5).
- [x] T023 [US1] `BoneGenerator`: atomic regeneration (replace existing bone dir), DI choice
  plumbed into manifest + injection builder (FR-014, FR-007).

## Phase 7: Manifest + validate compatibility

- [x] T024 [P] [US2] `manifest_builder.dart`: emit `di:`, `di_source:`, and (flutter mode)
  `flutter: true` + `entrypoint: lib/main.dart`; existing keys unchanged (FR-007).
- [x] T025 [US3] `bone validate`: accept packages declared in the bone's own `pubspec.yaml` as
  resolvable `package:` imports (FR-013, Edge: flutter_test import).
- [x] T026 [US1] Update existing skeleton unit tests to the working-slice emission shape; retire
  README-placeholder/TODO-stub expectations (FR-015).

## Phase 8: Acceptance scenarios (end-to-end)

- [x] T027 [US6] `sc_005_working_slice_test.dart`: generate profile-feature bone → `dart analyze`
  zero errors (scratch package) → run generated tests with `dart run` → all pass (SC-002, SC-003).
- [x] T028 [US5] `sc_005`: `--export` artifact exists, unpacks identical, < 50KB (SC-005, US5.AC1).
- [x] T029 [US4] `sc_005`: dependency chain A→B→C with `--include-deps` inlines the minimal
  transitive set; unrelated feature D absent; default declares-only (US4.AC1–AC4).
- [x] T030 [US3] `sc_005`: `--flutter` bone emits pubspec/main/page/widget-test; library mode
  emits none of them (US3.AC1–AC3).
- [x] T031 [US2] `sc_005`: `--di mock` vs `--di firebase` vs `--di auto` (detected + fallback)
  wiring + `bone.yaml` records (US2.AC1–AC4).
- [x] T032 [US5] Two features generated + exported into the same bones dir without conflicts
  (SC-006, US5.AC2).

## Phase 9: SDD closure

- [x] T033 Run `/speckit.analyze` cross-artifact drift check; fix drift (spec ↔ plan ↔ tasks ↔
  test-list ids).
- [x] T034 Record red evidence for every A/U behavior in `tdd/cycle-log` entries; green via
  `dart test test/plugins/skeleton/`.
- [x] T035 Write `tdd/verification.md` with ACTUAL counts, mutation/coverage honesty, and
  per-success-criterion PROVED/not-proved statements (SC-001..SC-006).
- [x] T036 `dart analyze && dart test && dart format .` green; commit spec artifacts
  (spec/plan/tasks/tdd) + implementation; push branch; open PR for #592.

## Implementation status of this PR

All 36 tasks completed in this PR. Evidence: `tdd/verification.md` (red → green counts, per-criterion honesty statements).
