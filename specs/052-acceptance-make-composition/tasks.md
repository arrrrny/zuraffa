# Tasks: `zfa tdd compose` — phase-2 acceptance make composition

**Input**: Design documents from `/specs/052-acceptance-make-composition/`
(spec.md, plan.md, research.md, data-model.md, contracts/contracts.md,
quickstart.md)

**Prerequisites**: plan.md (required), spec.md (required), research.md,
data-model.md, contracts/

**Tests**: MANDATORY — the tdd extension drives this feature test-first.
Behavior markers (`[A1]`, `[U1]`, …) trace tasks to
`specs/052-acceptance-make-composition/tdd/test-list.md`; `/speckit.tdd.run`
ticks a task's checkbox only when it can read a behavior id from it, and
every behavior's test is written and observed RED before the implementation
task that turns it green may run.

**Organization**: Tasks grouped by user story (spec.md US1–US4) with a
foundational phase for the discovery + fallback-planner services the P1
stories all consume.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Include exact file paths in descriptions

## Path Conventions

Repo-root package (matches plan.md): implementation under
`lib/src/plugins/tdd/{commands,services}/`, fast-tier tests under
`test/plugins/tdd/{commands,services}/`, slow-tier scenarios under
`test/plugins/tdd/scenarios/`.

---

## Phase 1: Setup

**Purpose**: register the compose command so the CLI surface exists

- [X] T001 Create `ComposeCommand` as a skeleton in
  `lib/src/plugins/tdd/commands/compose_command.dart` (flags: `--feature`,
  `--project`; outcome enum + summary printer) and register it in
  `lib/src/commands/tdd_command.dart` next to `WireCommand`; update
  `test/plugins/tdd/tdd_command_smoke_test.dart` to expect `compose` in
  `zfa tdd --help`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the pure discovery + fallback-planner services both the compose
command (US2) and the make fallback (US1) consume. Test-first: each group's
failing tests land before its implementation.

- [X] T002 [P] [U1] [U2] [U3] [U4] [U5] Write the failing discovery tests FIRST in
  `test/plugins/tdd/services/composition_targets_test.dart`: discovery =
  unit-kind test-list rows ∩ green cycle-log evidence ∩ existing subject
  files; zero anchors reported as no-green-units (not an error state, a
  typed result); a green unit with a missing subject file is a discovery
  failure naming the artifact; the compose target itself is never an anchor
  — observe red before the service exists (depends on T001 for imports
  only)
- [X] T003 [P] Implement `CompositionTargets` in
  `lib/src/plugins/tdd/services/composition_targets.dart` (pure-ish
  filesystem reader: test list via shared `TestListReader`, green evidence
  via `CycleEvidence`, subject paths via `ArtifactRegistry`; returns
  anchors or a typed failure; depends on T002 red)
- [X] T004 [P] [U6] [U7] [U8] [A9] Write the failing fallback-planner tests
  FIRST in `test/plugins/tdd/services/composition_planner_test.dart`: an
  acceptance summary + ≥1 anchor yields the plan `tdd compose <id>` →
  `build` (terminal build step, captured purposes); planner purity — the
  result depends only on (summary, anchors); SC-006 pin —
  `GenerationPlanner.plan()` plans are byte-identical to its pinned
  outputs (entity / CRUD / prose) — observe red
- [X] T005 [P] Implement `CompositionPlanner` in
  `lib/src/plugins/tdd/services/composition_planner.dart` (pure:
  `(BehaviorSummary, List<ComposableUnitSubject>) → GenerationPlan`;
  depends on T004 red)

---

## Phase 3: User Story 1+2 — compose command (US2 surface, US1's step)

**Purpose**: the `zfa tdd compose` command the fallback plan invokes.
Test-first.

- [X] T006 [A3] [A4] [A5] [A6] [A7] [A8] [U9] [U10] [U11] [U12] [U13] [U14]
  [U15] [U16] Write the failing compose-command tests FIRST in
  `test/plugins/tdd/commands/compose_command_test.dart` (fast tier,
  `TddFixture`-based, real CLI entry via `CliRunner`): wired path —
  certified-red acceptance behavior + green unit behavior + subject stubs
  → `composed` exit 0, subject rewritten with GENERATED stamp + anchor
  imports/references, paired test byte-identical (A3/A4/A8, US2.AC1/AC5);
  idempotent re-run → `already-composed` exit 0 (A5/U14, US2.AC2); no
  green units → `no-green-units` exit 1 (A6, US2.AC3); green unit with
  missing subject file → runner-error naming the artifact (A7, US2.AC4);
  not-certified-red → `not-certified-red` exit 1 (U11, FR-002);
  unrecognized stub shape → refusal, no rewrite (U15, FR-005); unknown id
  / ambiguity → named errors (U9/U10, FR-001); summary line final stdout
  on every path (U16, FR-006) — observe red
- [X] T007 Implement `ComposeCommand` in
  `lib/src/plugins/tdd/commands/compose_command.dart` following wire's
  shape (resolution rules, stub-signature parsing, ownership refusals,
  idempotence, `compose: behavior=... outcome=... feature=...` final-line
  contract; uses `CompositionTargets` + renders the composed subject;
  depends on T003, T006 red)

---

## Phase 4: User Story 1+3 — make composition fallback (the phase-2 flip)

**Purpose**: wire the fallback into the 047 make pipeline behind the
planner-refusal branch. Test-first.

- [X] T008 [A10] [A11] [A13] [A14] [A15] [U17] [U18] [U19] [U20] Write the
  failing make-fallback tests FIRST in
  `test/plugins/tdd/commands/make_command_test.dart` (extend the existing
  suite): acceptance-kind unexpressible behavior + green unit subjects →
  fallback plan executes (`compose` → `build` steps captured in the green
  entry's generation steps, A13/U19, US1.AC2 / FR-010) and make reports
  `green`; acceptance-kind with zero anchors → `unexpressible` honest stop
  (A10, FR-009, SC-003); unit-kind unexpressible → `unexpressible` with NO
  fallback attempt (A11/U17, SC-004); malformed test list → fail-closed
  `unexpressible` (U18, FR-007); failed compose step → `generation-error`,
  no green entry (A14/U20, US4.AC2/FR-010); failed build after a composed
  subject → `generation-error`, no green entry (A15, US4.AC3) — observe red
- [X] T009 Implement the composition fallback in
  `lib/src/plugins/tdd/commands/make_command.dart`: on
  `!plan.isExpressible`, resolve the behavior's test-list row kind
  (shared `TestListReader`); acceptance-kind → discover anchors
  (`CompositionTargets`) and, when ≥ 1, execute
  `CompositionPlanner.plan(...)` through `PipelineRunner` with the same
  misfire-stop + evidence recording as the primary plan; otherwise report
  `unexpressible` unchanged (depends on T003, T005, T008 red)

---

## Phase 5: User Story 1 — real-pipeline phase-2 flip (acceptance e2e)

**Purpose**: the SC-001 proof — the scripted flip's real-pipeline
counterpart. Test-first, slow tier.

- [X] T010 [A1] [A2] [A12] Write the failing scenario tests FIRST in
  `test/plugins/tdd/scenarios/sc_021_acceptance_composition_e2e_test.dart`
  (slow tier, pure exec forwarder to the REAL `bin/zfa.dart` — SC-017/018
  provisioning): SC-001 — prose acceptance + unit behavior driven
  `gen → verify-red → run` to all-DONE with NO fake-zfa scripting of the
  phase-2 outcome; the phase-2 make flips green via composition, the
  composed subject references the unit subject, and A1's green entry
  carries the compose step (A1/A2, SC-001/SC-002); SC-005 — the
  entity-bearing acceptance path stays all-DONE (A12, no regression) —
  observe red
- [X] T011 [A1] Fix any real-pipeline gaps the scenario exposes (argument
  plumbing, anchor import paths, build step behavior in fixtures) and
  re-run SC-021 to green (depends on T010 red)

---

## Phase 6: Verification & polish

- [X] T012 Run the regression guards and record evidence:
  existing driver/deferral suites (sc_013–sc_016), planner unit suite,
  SC-018 entity-bearing e2e, `dart analyze`, `tools/run_tests_chunked.sh`,
  `dart format .`; append the verification summary to
  `specs/052-acceptance-make-composition/tdd/verification.md`
  (/speckit.tdd.verify)
