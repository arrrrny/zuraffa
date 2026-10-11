# Tasks: Platform-typed acceptance scenarios are first-class SKIN lane rows

**Input**: Design documents from `/specs/1432-platform-lane-skin-plan/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plan-cli-contract.md, quickstart.md

**Tests**: TDD per the spec-whole flow — every behavior gets a failing test first (`tdd/test-list.md` is the behavior list; this file carries the non-behavior remainder).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1/US2/US3)

## Path Conventions

Repo-local TDD plugin: `lib/src/plugins/tdd/` (services + commands), tests in `test/plugins/tdd/`.

## Phase 1 — Setup

- [x] T001 Confirm the defect surface on the head tree: `renderSkinPlan`/`renderEnginePlan` in `lib/src/plugins/tdd/services/lane_split.dart` have no platform section, and the split refusal loop in `lib/src/plugins/tdd/commands/plan_command.dart` (the `lane == null` / noFlutter pass) is the guard site (research.md R1–R3)

## Phase 2 — Foundational

- [x] T002 Seed the shared fixture helper for the regression suite: a hermetic temp spec with a `## Lanes` SKIN lane declaring acceptance- and platform-typed acceptance scenarios (Type markers on every scenario), in `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart`

## Phase 3 — User Story 1: every routed behavior renders as a lane row (P1)

**Goal**: A platform-typed acceptance scenario renders in its lane plan's acceptance outer-loop table exactly like an acceptance-typed one.

**Independent Test**: Plan the fixture spec; `04-SKIN.md`'s outer-loop table carries the platform row with the same columns; exit 0.

- [x] T003 [P] [US1] [behavior: U-1432-1, U-1432-2] (MANDATORY) RED: registry the renderer rows in `test/plugins/tdd/services/` — `renderSkinPlan` and `renderEnginePlan` place a platform-kind `LaneRow` in the acceptance section with the 4-column shape (fails: row absent today)
- [x] T004 [US1] GREEN: include `BehaviorKind.platform` in the acceptance section filter of `renderSkinPlan` and `renderEnginePlan` in `lib/src/plugins/tdd/services/lane_split.dart`
- [x] T005 [US1] [behavior: A-1432-1] (MANDATORY) RED→GREEN: CLI rows in `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart` — plan the fixture spec (exit 0), assert the SKIN artifact's outer-loop table carries BOTH the acceptance-typed and platform-typed ids; record the red against the unfixed tree first, then re-run green after T004
- [x] T006 [US1] [behavior: A-1432-2] (MANDATORY) Assert the log ↔ artifact invariant in the same suite: every `route: <id> -> ` id the plan prints appears as a row in the lane plan the log names (SC-002)

## Phase 4 — User Story 2: refuse instead of dropping (errors-are-an-API) (P2)

**Goal**: A routed behavior kind no lane section renders refuses the plan (exit 2, no artifacts) naming id/kind/criterion.

**Independent Test**: Plan a spec whose SKIN lane carries a theme-typed scenario (today's reachable no-home kind); exit non-zero with the #1432 refusal; no lane artifacts written.

- [x] T007 [P] [US2] [behavior: A-1432-3, U-1432-3] (MANDATORY) RED: refusal rows in `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart` — a theme-typed scenario in the SKIN lane plans to exit 2 with the refusal naming id/kind/criterion and writes no `04-ENGINE.md`/`04-SKIN.md`/`04-CONTRACT.md` (fails: today it exits 0 and drops the row)
- [x] T008 [US2] GREEN: add the kind-without-home guard to the split refusal loop in `lib/src/plugins/tdd/commands/plan_command.dart` (home sets: engine {acceptance, platform, widget, unit, ffi}, skin {acceptance, platform, widget, unit}; BOTH requires both; contract rows excluded — open #1419), with the `--> fix:` remedy naming the Type marker to change

## Phase 5 — User Story 3: lane accounting stays honest (P3)

**Goal**: The plan's rendered behavior counts equal the artifact's data-row count per lane.

**Independent Test**: Plan the fixture spec; the summary's SKIN behavior count equals the SKIN artifact's outer-loop+inner-loop data-row count.

- [x] T009 [US3] [behavior: A-1432-4] (MANDATORY) Row-count rows in `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart` — the plan summary's SKIN count equals the number of behavior data rows parsed from `04-SKIN.md`, and the platform row is counted (fails as written pre-T004 because the row is absent; green after)

## Phase 6 — Polish & cross-cutting

- [x] T010 [behavior: U-1432-4] (MANDATORY) Regression sweep (targeted, no whole-suite runs): `plan_lanes_1000_test.dart`, `split_command_1000_test.dart`, `bug_1419`/contract-lane suites if present, `bug_1318_noflutter_event_prose_test.dart`, and the single-file plan tests — all green, no shape drift in acceptance/widget/unit/ffi rendering
- [x] T011 `dart format` on touched files + `dart analyze lib/src/plugins/tdd` clean; update `specs/1432-platform-lane-skin-plan/quickstart.md` verification steps only if the contract shifted during the loop

## Dependencies

- T001 → T002 → (T003, T005, T006 behaviors; T007; T009)
- T004 depends on T003 (red first); T005/T006 go green after T004
- T008 depends on T007 (red first)
- T009 depends on T004
- T010/T011 last

## Parallel Execution Examples

- T003 (service-test rows) and T007 (CLI refusal rows) touch different files — parallelizable after T002.
- T004 and T008 are independent edits (different files) once their reds are recorded.

## Implementation Strategy

- MVP = US1 (the silent drop): T003–T006 alone make platform scenarios first-class SKIN rows and pin log↔artifact agreement.
- US2 (T007–T008) closes the class: no kind can silently vanish again.
- US3 (T009) pins the accounting invariant that makes regressions visible in one assertion.
- The contract-kind path stays untouched for #1419.
