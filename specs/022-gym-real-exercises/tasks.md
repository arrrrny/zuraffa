# Tasks: Build Real GYM Exercises for zuraffa, zorphy, zikzak_inappwebview, vendure-flutter-sdk

**Input**: Design documents from `specs/022-gym-real-exercises/`

**Prerequisites**: `plan.md` (required), `spec.md` (required for user stories).

**Tests**: TDD extension is enabled; tests are written FIRST (red), then
implementation (green), then refactor.

**Organization**: Tasks grouped by user story; MVP first (Story 1 →
warmup is the gate for every other story). zuraffa already has warmup
reps + 2 graded exercises — this feature ADDS one new exercise to
zuraffa and ships reference `.gym/` templates for the other three
packages.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies).
- **[Story]**: Which user story this task belongs to.

## Path Conventions

- zuraffa's own `.gym/`: at repo root.
- Reference templates: `examples/gym-templates/<pkg>/.gym/`.
- Shared helper: `.gym/lib/drop_card.dart`.
- Tests: `test/plugins/gym/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the shared DROP CARD helper and the
`examples/gym-templates/` directory.

- [x] T001 Create `.gym/lib/` directory for shared GYM helper code.
- [x] T002 [P] Implement `DropCard` helper in `.gym/lib/drop_card.dart` — enforces Did/Expected/Happened/Where fields.
- [x] T003 [P] Create `examples/gym-templates/` directory + README.

**Checkpoint**: Shared infra exists; no behavior yet.

---

## Phase 2: Foundational (DROP CARD contract)

**Purpose**: The DROP CARD format is the contract every exercise's
mis-fire path depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T004 [P] `test/plugins/gym/drop_card_test.dart` — DROP CARD has all four required fields; throws if any is missing; output is plain-text markdown.
- [x] T005 Implement `DropCard.emit(...)` + `DropCard.writeTo(...)` to satisfy T004.

**Checkpoint**: Foundation ready; user-story implementation can proceed in parallel.

---

## Phase 3: User Story 1 — Warmup reps across all four packages (Priority: P1) 🎯 MVP

**Goal**: Each of the four packages carries mandatory warmup reps
(deps + build + one authenticated smoke call). zuraffa already has
them; the three reference templates ship them.

**Independent Test**: each package's warmup reps exit 0 (zuraffa's
existing reps continue to pass — FR-008 / SC-003).

### Implementation for User Story 1

- [x] T006 [P] [US1] Write `examples/gym-templates/zorphy/.gym/warmup/{01-deps,02-build,03-smoke}.dart`.
- [x] T007 [P] [US1] Write `examples/gym-templates/zikzak_inappwebview/.gym/warmup/{01-deps,02-build,03-smoke}.dart`.
- [x] T008 [P] [US1] Write `examples/gym-templates/vendure-flutter-sdk/.gym/warmup/{01-deps,02-build,03-smoke}.dart`.
- [x] T009 [P] [US1] Write each template's `gym.yaml` with the warmup entries.
- [x] T010 [US1] Verify zuraffa's existing warmup reps still pass (no regression — FR-008 / SC-003).

**Checkpoint**: User Story 1 functional; warmup reps exist for every package. SC-003 provable for zuraffa.

---

## Phase 4: User Story 2 — Graded exercises prove real-world capability (Priority: P1)

**Goal**: Each package has at least one graded exercise representing a
genuine dev task (not a re-skinned unit test) with `verifyCommand` +
`evaluate` (FR-003).

**Independent Test**: each package's graded exercise exits 0 (or
structured non-zero with DROP CARD on mis-fire).

### Tests for User Story 2 (RED FIRST)

- [x] T011 [P] [US2] `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — the new zuraffa exercise's structure is correct (sandbox setup, assertion, DROP CARD path).
- [x] T012 [P] [US2] `test/plugins/gym/gym_templates_test.dart` — each reference template's `gym.yaml` has canonical keys + at least one graded exercise.

### Implementation for User Story 2 (GREEN)

- [x] T013 [US2] Implement `.gym/exercise-extend-zfa-cli.dart` — the new zuraffa graded exercise (genuine dev task: scaffold a `zfa <name>` subcommand).
- [x] T014 [US2] Add `extend-zfa-cli` entry to `.gym/gym.yaml`'s `exercises:` list.
- [x] T015 [P] [US2] Implement `examples/gym-templates/zorphy/.gym/exercise-store-mutation.dart`.
- [x] T016 [P] [US2] Implement `examples/gym-templates/zikzak_inappwebview/.gym/exercise-js-bridge-roundtrip.dart`.
- [x] T017 [P] [US2] Implement `examples/gym-templates/vendure-flutter-sdk/.gym/exercise-fetch-product.dart`.
- [x] T018 [P] [US2] Add each reference template's graded exercise entry to its `gym.yaml`.

**Checkpoint**: User Story 2 functional; every package has at least one graded exercise. SC-001 provable.

---

## Phase 5: User Story 3 — gym.yaml consumable by miki GYM runner (Priority: P2)

**Goal**: Every package's `gym.yaml` matches the artifact format the
miki runner consumes (FR-004).

**Independent Test**: the miki runner parses every `gym.yaml` without
errors (we can't run miki in CI, so we test the YAML structure
directly).

### Tests for User Story 3 (RED FIRST)

- [x] T019 [P] [US3] `test/plugins/gym/gym_templates_test.dart` — every `gym.yaml` has `name`, `version`, `warmup`, `exercises`; each exercise has `id`, `brief`, `setup`, `verifyCommand`, `evaluate`.
- [x] T020 [P] [US3] `test/plugins/gym/gym_templates_test.dart` — zuraffa's existing entries (01-deps, 02-build, 03-smoke, generate-feature, agent-rewrite-zfa-only) remain valid.

### Implementation for User Story 3 (GREEN)

- [x] T021 [US3] Verify each `gym.yaml` is well-formed YAML (no parse errors).
- [x] T022 [US3] Verify each exercise entry has every canonical key.

**Checkpoint**: User Story 3 functional; miki can consume every `gym.yaml`.

---

## Phase 6: User Story 4 — Mis-fires produce DROP CARDs (Priority: P2)

**Goal**: Any unexpected outcome during exercise execution produces a
DROP CARD with Did / Expected / Happened / Where (FR-006 / SC-004).

**Independent Test**: trigger a known mis-fire condition; assert a
DROP CARD with all four fields is emitted and exit is non-zero.

### Tests for User Story 4 (RED FIRST)

- [x] T023 [P] [US4] `test/plugins/gym/drop_card_test.dart` — DROP CARD emitted with all four fields on mis-fire.
- [x] T024 [P] [US4] `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — exercise exits non-zero on mis-fire AND emits a DROP CARD.

### Implementation for User Story 4 (GREEN)

- [x] T025 [US4] Wire `DropCard.emit(...)` into the new zuraffa exercise's mis-fire path.
- [x] T026 [US4] Wire `DropCard.emit(...)` into each reference template's mis-fire path.

**Checkpoint**: User Story 4 functional; mis-fires produce structured DROP CARDs. SC-004 provable.

---

## Phase 7: Hardening

**Purpose**: Edge-case coverage, final cross-artifact drift check,
verify no regression.

- [x] T027 [P] Edge case: exercise that fails to spawn (binary missing) emits DROP CARD with `Where` naming the spawn attempt.
- [x] T028 [P] Edge case: exercise that produces unexpected output emits DROP CARD with `Happened` showing the actual output.
- [x] T029 Run `dart analyze` and `dart test` on the full project; ensure zero new errors and all GYM tests green.
- [x] T030 Run `dart format .` and confirm `git diff --stat` shows no remaining formatting diffs on added files.

**Checkpoint**: Feature complete; ready for PR.

---

## Cross-Artifact Drift Check

After all tasks complete, the `/speckit-analyze` step verifies:

- Every FR-xxx in `spec.md` maps to at least one task above.
- Every SC-xxx in `spec.md` maps to at least one Independent Test above.
- Every behavior in `tdd/test-list.md` maps to a task ID here.
- No task references a file not declared in `plan.md`'s structure tree.

Drift findings resolved inline during implementation (none outstanding
at delivery time — see `tdd/verification.md`).
