# Tasks: `zfa tdd make`

**Input**: Design documents from `/specs/047-tdd-make/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/make.md

**Tests**: MANDATORY (tdd.plan) — this feature is a TDD-loop step; spec
SC-001..SC-006 demand automated proof. Every behavior in `tdd/test-list.md`
has a test task below, and each test must be observed failing before its
implementation task starts. Command/scenario tests are `@Tags(['slow'])`
subprocess tests mirroring `verify_red_command_test.dart`; service tests
stay fast.

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Test fixture extensions shared by all stories

- [ ] T001 Extend `TddFixture` in `test/plugins/tdd/helpers/tdd_fixture.dart` with: a certified-red seed (registry record + cycle-log red entry + failing test + compiling stub subject), a fake `zfa` executable script the pipeline runner can invoke (logs argv, exits per a fixture-controlled plan, and exposes a deterministic production-source mutation hook), plus a source-backed sibling test that the hook can break while leaving the generated source in place for inspection

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models and services every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] [U1] [U2] Add `MakeOutcome` enum (green, not-certified-red, drift, unexpressible, generation-error, regression, runner-error), `GenerationPlan`, `GenerationStepSpec`, and `GenerationStep` value objects per data-model.md in `lib/src/plugins/tdd/models/generation_plan.dart`
- [ ] T003 [P] [U21] [U22] Extend `CycleLogEntry` with `generationSteps` (default empty) and render the `generation:` + `suite:` blocks in green-entry `toMarkdown()` per contracts/make.md, in `lib/src/plugins/tdd/models/cycle_entry.dart`
- [ ] T004 [P] [U19] [U20] Extend `SingleTestRunner` with suite-template loading (`suite` key, same parsing path as `loadSingleTemplate`) and a `runSuite()` capture method returning exit code + output, in `lib/src/plugins/tdd/services/runner.dart`
- [ ] T005 [U3] [U4] [U5] [U6] [U7] Implement `generation_planner.dart`: map a behavior row (target, classification, description) to a minimal ordered `GenerationPlan` (entity → `entity create`; crud/use-case → `make` with preset/methods; always ending in `build`), returning `unexpressibleReason` when unmappable, in `lib/src/plugins/tdd/services/generation_planner.dart`
- [ ] T006 [U8] [U9] [U10] [U11] [U12] [U13] Implement `pipeline_runner.dart`: resolve the zfa entrypoint (`--zfa-bin` override → running CLI's `Platform.script` when from source → `zfa` on PATH; unresolvable = misfire), execute each `GenerationStepSpec` via `Process.run` in the target working directory, capture `GenerationStep(command, exitCode, output)`, stop the plan on first failing step, in `lib/src/plugins/tdd/services/pipeline_runner.dart`
- [ ] T007 [U14] [U15] [U16] [U17] [U18] Implement `suite_guard.dart`: run the profile `suite` command, validate that both baseline and guard processes started and produced usable snapshots (a non-zero exit requires named failures), parse failing test identifiers, and diff guard-minus-baseline to surface only NEW failures by name, in `lib/src/plugins/tdd/services/suite_guard.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Turn a certified-red behavior green via generation (Priority: P1) 🎯 MVP

**Goal**: `zfa tdd make <id>` on a certified-red behavior generates the
implementation through pipeline sub-processes, turns the target test green,
keeps the suite clean, and logs green evidence with the recorded generation
steps.

**Independent Test**: Fixture with certified-red behavior and scripted fake
pipeline → exit 0, summary `outcome=green`, 8-field green entry with
`generation:` block, test file byte-identical (quickstart.md scenario 3).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [ ] T008 [P] [US1] [U3] [U4] [U5] [U6] Planner test: entity-bearing and CRUD behaviors map to minimal ordered plans ending in `build`, in `test/plugins/tdd/services/generation_planner_test.dart`
- [ ] T009 [P] [US1] [U8] [U9] [U10] [U13] Pipeline runner test: steps execute in order against the fake zfa script, each captured with command/exitCode/output, first failure stops the plan, in `test/plugins/tdd/services/pipeline_runner_test.dart`
- [ ] T010 [P] [US1] [U26] [U28] Command happy-path test (slow): certified-red fixture + fake pipeline → exit 0, target test passes, green entry complete per contracts/make.md, and the complete target `test/` directory tree (all paths and bytes) is identical before and after, in `test/plugins/tdd/make_command_test.dart`
- [ ] T011 [P] [US1] [A1] [A2] [A3] Acceptance scenario driving the real CLI for the red→green path end-to-end (stays red until US1 completes) in `test/plugins/tdd/scenarios/sc_005_turns_red_green_test.dart`

### Implementation for User Story 1

- [ ] T012 [US1] [U23] [U24] [U25] [U26] [U30] Implement `MakeCommand.run()`: mirror `verify_red_command.dart` conventions (`--feature` validation, registry resolution, `print()` summary, `exitCode` assignment, misfire-stop try/catch); orchestrate precondition → drift check → planner → pipeline runner → target test via `runner.dart` → suite guard → green evidence via `CycleLog`, in `lib/src/plugins/tdd/commands/make_command.dart`
- [ ] T013 [US1] [U28] [U29] Implement green-evidence assembly (generation steps + suite baseline/guard counts + runner capture) and the `make: behavior=<id> outcome=green feature=<f>` summary line, in `lib/src/plugins/tdd/commands/make_command.dart`

**Checkpoint**: US1 fully functional and independently testable; A1–A3 green

---

## Phase 4: User Story 2 - Refuse without certified red (Priority: P1)

**Goal**: No red evidence, unknown id, or already-green drift → non-zero
stop before any generation, with named remediation.

**Independent Test**: Fixture variants missing each precondition → no fake
pipeline invocation recorded, named outcomes (quickstart.md scenario 4).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [ ] T014 [P] [US2] [U23] [U24] [U25] Precondition tests (slow): no red evidence → `not-certified-red` with verify-red remediation; unknown id → named id + gen remediation; already-green target → `drift`; assert the fake pipeline script was never invoked, in `test/plugins/tdd/make_command_test.dart`
- [ ] T015 [P] [US2] [A4] [A5] [A6] Acceptance scenario for all three refusals through the real CLI in `test/plugins/tdd/scenarios/sc_006_requires_certified_red_test.dart`

### Implementation for User Story 2

- [ ] T016 [US2] [U23] [U25] Implement the precondition gate: red-evidence lookup in `cycle-log.md`, registry check, and the pre-generation drift check that re-runs the target test via the profile `single` command (pass → `drift` stop), in `lib/src/plugins/tdd/commands/make_command.dart`

**Checkpoint**: US1 AND US2 both work independently; A4–A6 green

---

## Phase 5: User Story 3 - Regression guard via the full suite (Priority: P1)

**Goal**: After the target test goes green, the full suite runs; NEW failures
(relative to the pre-generation baseline) fail the run and write no green
entry; pre-existing failures are tolerated.

**Independent Test**: Fixture whose fake pipeline breaks a sibling test →
non-zero `regression` naming the sibling; fixture with a pre-existing failure
unrelated to the change → still certifies green.

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [ ] T017 [P] [US3] [U14] [U15] [U16] [U17] [U18] Suite guard test: failed-test parsing from canned `dart test` outputs, NEW-failure diff (incl. pre-existing-failure tolerated and fix+break nets failure), in `test/plugins/tdd/services/suite_guard_test.dart`
- [ ] T018 [P] [US3] [U15] [U17] Command regression test (slow): sibling-breaking pipeline → non-zero, regressed test named, no green entry, generated source left in place, in `test/plugins/tdd/make_command_test.dart`
- [ ] T019 [P] [US3] [A7] [A8] [A9] Acceptance scenario for the regression guard in `test/plugins/tdd/scenarios/sc_007_regression_guard_test.dart`

### Implementation for User Story 3

- [ ] T020 [US3] [U15] [U16] Wire the guard into the command: baseline snapshot before generation, guard snapshot after the target test passes, NEW-failure report with named tests on stderr, in `lib/src/plugins/tdd/commands/make_command.dart`

**Checkpoint**: US1–US3 all work independently; A7–A9 green

---

## Phase 6: User Story 4 - Misfire-stop on unexpressible behaviors (Priority: P1)

**Goal**: Pipeline-inexpressible behaviors and failing generation steps stop
non-zero with the unmet capability / failing step named; test file and cycle
log untouched.

**Independent Test**: Unmappable behavior fixture → `unexpressible` naming
the capability; failing-step fixture → `generation-error` naming the step
(quickstart.md scenario 5).

### Tests for User Story 4 ⚠️ (write first, watch fail)

- [ ] T021 [P] [US4] [U7] Planner misfire test: behaviors with no pipeline mapping return `unexpressibleReason` phrased in behavior terms, in `test/plugins/tdd/services/generation_planner_test.dart`
- [ ] T022 [P] [US4] [U10] [U12] [U27] Command misfire test (slow): unexpressible behavior and failing-step fixtures → non-zero, named outcome, zero writes to test/cycle-log, in `test/plugins/tdd/make_command_test.dart`
- [ ] T023 [P] [US4] [A10] [A11] [A12] Acceptance scenario for misfire honesty in `test/plugins/tdd/scenarios/sc_008_misfire_stop_test.dart`

### Implementation for User Story 4

- [ ] T024 [US4] [U27] Implement per-outcome stderr reports with remediation hints (unexpressible → gap protocol; generation-error → failing command + output tail; runner-error → profile/tooling check), in `lib/src/plugins/tdd/commands/make_command.dart`

**Checkpoint**: US1–US4 all work independently; A10–A12 green

---

## Phase 7: User Story 5 - Machine-readable result contract (Priority: P2)

**Goal**: Stable summary line + exit-code contract consumable by
`zfa tdd run` and CI.

**Independent Test**: Contract test pins the summary format for every
outcome class (spec SC-006).

### Tests for User Story 5 ⚠️ (write first, watch fail)

- [ ] T025 [P] [US5] [U29] Summary contract test: every outcome produces the final-line format `make: behavior=<id-or--> outcome=<outcome> feature=<feature-or-unknown>` (including invalid `--feature` and registry-resolution failures), and exit 0 exactly on `green`, in `test/plugins/tdd/make_command_test.dart`
- [ ] T030 [P] [US5] [A13] [A14] Acceptance scenario asserting that same placeholder-aware summary/exit-code contract through the real CLI across resolved and pre-resolution outcome classes, in `test/plugins/tdd/scenarios/sc_009_summary_contract_test.dart`

### Implementation for User Story 5

- [ ] T026 [US5] [U29] Emit the summary line as the final stdout line on every code path, including invalid `--feature`, registry-resolution, and misfire errors; use `behavior=-` when no id is available and `feature=unknown` when no valid feature is available, in `lib/src/plugins/tdd/commands/make_command.dart`

**Checkpoint**: All user stories independently functional; A13–A14 green

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T027 Run `dart analyze` on all touched files and fix findings
- [ ] T028 Run `dart test test/plugins/tdd/` (fast) and `dart test --tags slow test/plugins/tdd/` and confirm both green
- [ ] T029 Execute quickstart.md scenarios 1–5 verbatim and record results in `specs/047-tdd-make/tdd/` evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — start immediately
- **Foundational (Phase 2)**: depends on nothing (T002–T004 parallel; T005–T007 after T002); BLOCKS all user stories
- **US1 (Phase 3)**: depends on Phase 2 + T001
- **US2 (Phase 4)**: depends on US1 command skeleton (T012)
- **US3 (Phase 5)**: depends on US1; US2 independent
- **US4 (Phase 6)**: depends on US1 (T012) and planner (T005)
- **US5 (Phase 7)**: depends on US1; independent of US2–US4
- **Polish (Phase 8)**: after all stories

### Parallel Opportunities

- T002, T003, T004 in parallel (different files); T005–T007 in parallel after T002
- T008, T009, T010, T011 in parallel (different test files)
- T017, T018, T019 in parallel; T021, T022, T023 in parallel; T025, T030 in parallel

## Parallel Example: User Story 1

```bash
# Launch all US1 tests together:
Task: "Planner test in test/plugins/tdd/services/generation_planner_test.dart"
Task: "Pipeline runner test in test/plugins/tdd/services/pipeline_runner_test.dart"
Task: "Command happy-path test in test/plugins/tdd/make_command_test.dart"
Task: "Acceptance scenario in test/plugins/tdd/scenarios/sc_005_turns_red_green_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 → foundation ready
2. Phase 3 (US1) → red→green certification working → **STOP and VALIDATE**
3. Phases 4–7 harden the gate without changing the happy path

### Incremental Delivery

Each story lands behind the same command surface; refusals (US2), the
regression guard (US3), misfire honesty (US4), and the machine contract
(US5) are separable increments that never regress US1's certification path.

## Notes

- Service tests are fast tier; command + scenario tests are `@Tags(['slow'])`
  subprocess tests, mirroring the merged 046 layout.
- The command mutates: `cycle-log.md` (append, only on green) and `lib/` of
  the TARGET project (only through recorded pipeline sub-processes). It never
  touches `test/` in the target project.
- Misfire-stop: any step that cannot complete stops the command non-zero with
  a named outcome (spec FR-011).
- Acceptance scenario task T030 was appended by `/speckit.tdd.plan` (ids
  continue the sequence; no existing task was renumbered).
