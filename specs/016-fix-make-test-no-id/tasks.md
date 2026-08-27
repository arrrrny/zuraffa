# Tasks: make --test regenerates tests for id-less entities

**Input**: Design documents from `/specs/016-fix-make-test-no-id/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/make-command-id-gating.md

**Tests**: Required — FR-009 mandates a regression test, and the repo's workflow (AGENTS.md validation guidance) is test-first.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Include exact file paths in descriptions

## Path Conventions

- Single project: production code in `lib/src/`, tests in `test/` (matches plan.md structure decision)
- Verification fixture `../zikzak_demo/` lives OUTSIDE the repo (scratch, not committed)

---

## Phase 1: Setup

**Purpose**: Branch and SDD artifacts exist; reproduction confirmed.

- [x] T001 Create branch `016-fix-make-test-no-id` (= feature dir name, per AGENTS.md)
- [x] T002 Spec-kit artifacts: spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md
- [x] T003 Reproduce the defect on unmodified master via the `../zikzak_demo` stand-in (done: exit 1, exact issue output captured)

---

## Phase 2: Foundational — RED tests first (blocks all stories)

**Purpose**: Write the regression tests that pin the NEW contract (C1/C3/C7) and prove they FAIL on master.

### Tests (write FIRST, verify RED)

- [x] T010 [US1] In `test/commands/make_command_test.dart`, extend the `MakeCommand #307 identity contract` group with a `#508` subgroup: id-less entity (ChatMessage-style: first field an ENUM, then `String content`) + `--test` only → must NOT contain `has no id field`, must exit 0, and the generated get-test must reference the real field constant (`ChatMessageFields.content`, not `.id`, not `.role`). Include a second case asserting FR-006: an explicit `--query-field=content` on the same id-less entity is preserved verbatim (no auto-resolution override). Use the `runCapturing` pattern (`CliRunner(exitOnCompletion: false)`) per the comment at the throw site. Verify the tests FAIL on unmodified master.
- [x] T011 [US2] Same subgroup: the same id-less entity + an id-dependent plugin (e.g. `zfa make ChatMessage usecase ...`) → must still throw (`has no id field` + the three remediation hints) via `runCapturing`, with NO files written. Verify this one PASSES on master already (it pins current behaviour).
- [x] T012 [P] [US1] In `test/utils/entity_field_resolver_test.dart`, add a `resolveRepresentativeField` group: prefers first non-nullable String; falls back to first int; skips enum-typed fields entirely; skips List/Map; returns null when no usable field; strips nullable markers from the type. Verify RED (API does not exist yet → compile error counts as RED).

**Checkpoint**: T010/T012 red, T011 green. Do not start implementation before this holds.

---

## Phase 3: User Story 1 — `--test` regenerates for id-less entities (Priority: P1) 🎯 MVP

**Goal**: `zfa make <E> --test --force` exits 0 for an id-less entity and the regenerated tests reference a real field.

**Independent Test**: run the T010 test file; run `zfa make AuthRequest --test --force` in `../zikzak_demo`.

### Implementation

- [x] T020 [US1] `lib/src/utils/entity_field_resolver.dart`: add `static EntityFieldInfo? resolveRepresentativeField({required String entityName, required String projectRoot, String entityOutputDir = defaultEntityOutputDir})` implementing the C3 preference chain (non-nullable String → non-nullable int → nullable String/int → double/num/bool/DateTime; never custom/enum types; null when nothing usable). Reuse `parseEntityFields`.
- [x] T021 [US1] `lib/src/commands/make_command.dart`: add named `static const Set<String> _idDependentPlugins` = {repository, datasource, usecase, controller, presenter, service, provider, route, view, gql, graphql, sqlite, api, sync} next to `_valueObjectRootPlugins`, with a doc comment referencing #508.
- [x] T022 [US1] `lib/src/commands/make_command.dart` else-branch (no-id): throw ONLY when `activePlugins.any((p) => _idDependentPlugins.contains(p.id))`; otherwise call `resolveRepresentativeField` and populate `context.data['query-field']`/`['query-field-type']` under the same `wasParsed`/default-value guards the `hasId` branch uses. #307 print block stays byte-identical inside the gated arm.
- [x] T023 [US1] GREEN: `dart test test/commands/make_command_test.dart test/utils/entity_field_resolver_test.dart` — all pass, including the untouched #307 tests.

**Checkpoint**: US1 independently testable (T010 green + demo `zfa make AuthRequest --test --force` exits 0).

---

## Phase 4: User Story 2 — #307 loud failure preserved (Priority: P1)

**Goal**: Full/id-dependent `zfa make` on an id-less entity still fails loudly, unchanged.

**Independent Test**: T011 plus the pre-existing suites below.

- [x] T030 [US2] Run untouched #307/#321 suites: `dart test test/commands/make_command_test.dart test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart test/regression/issue_294_entity_without_id_test.dart` — all green.
- [x] T031 [US2] In `../zikzak_demo`: `zfa make AuthRequest --force` (id-dependent active) → exit 1 + exact #307 message/hints; `--id-field=content --id-field-type=String` variant → still exit 1 (#321 contract).

---

## Phase 5: User Stories 3+4 — control entity and the seven demo entities (Priority: P2)

**Goal**: PriceAlert unchanged; all seven named entities regenerate and their tests pass.

- [x] T040 [US3] `../zikzak_demo`: `zfa make PriceAlert --test --force` → exit 0, tests still reference `PriceAlertFields.id`, `dart test -N PriceAlert` green.
- [x] T041 [US4] `../zikzak_demo`: loop `zfa make <E> --test --force` over AuthRequest, Barcode, DeviceInfo, GroceryPriceComparison, GroceryPriceResult, MetricDetail, StorePrice → all exit 0.
- [x] T042 [US4] `../zikzak_demo`: `dart test test/` — regenerated suites pass; grep the seven entities' tests for `Fields.id` → no hits; record exact pass/fail counts and any pre-existing unrelated failure (e.g. the DeviceInfo/zuraffa umbrella-export name collision native to the pure-Dart fixture).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T050 `dart analyze` on the repo (zero new issues).
- [x] T051 Full fast suite: `dart test` from repo root — green or pre-existing failures explicitly listed.
- [x] T052 Run `specs/016-fix-make-test-no-id/quickstart.md` flow end-to-end once.
- [x] T053 Commit (fix + spec artifacts), push branch, open PR closing #508 with verification output.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: complete.
- **Foundational (Phase 2)**: RED tests — BLOCKS all implementation (test-first gate).
- **US1 (Phase 3)**: depends on Phase 2; T020 → T022 (resolver API before its call site); T021 parallel-safe with T020.
- **US2 (Phase 4)**: depends on Phase 3 (the gate must exist to prove it preserved the throw).
- **US3+US4 (Phase 5)**: depend on Phase 3; T040 parallel-safe with T041/T042.
- **Polish (Phase 6)**: last.

### Within Each User Story

- Tests written and verified RED before implementation (Phase 2 covers all stories' tests).
- Resolver API before command wiring.
- Story complete before moving to the next priority.

---

## Implementation Strategy

MVP = Phase 2 + Phase 3 (US1): after that, `--test` unblocks. Then Phase 4 proves the guard, Phase 5 proves it at the seven-entity scale, Phase 6 ships.

## Notes

- Never touch `lib/src/plugins/test/builders/*` (maintainer's uncommitted work; mergeability constraint).
- Never hand-edit generated code — the demo fixture is produced exclusively by zfa commands.
- The #307 diagnostic text is contract; copy nothing, reword nothing.
