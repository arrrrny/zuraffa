# Tasks: `zfa tdd run`

**Input**: Design documents from `/specs/049-tdd-run/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/run.md

**Tests**: MANDATORY (tdd.plan) — this feature is the TDD-loop driver; spec
SC-001..SC-006 demand automated proof. Every behavior in `tdd/test-list.md`
has a test task below, and each test must be observed failing before its
implementation task starts. Service tests are fast tier; driver/scenario
tests are `@Tags(['slow'])` with scripted fake step binaries (steps 047/048
may not be merged yet).

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Fixture extensions shared by all stories

- [x] T001 Extend `TddFixture` in `test/plugins/tdd/helpers/tdd_fixture.dart` with: test-list seeding in the 4-column plan format (`| id | behavior | traces | state |`), `run-state.json` seeding, green-evidence seeding, multi-behavior mixed-state fixtures, and a scripted fake step binary directory (gen/verify-red/make/refactor scripts with fixture-controlled outcomes and an invocation log)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Services and model extensions every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T002 [P] [U1] [U2] [U3] Implement `test_list_reader.dart`: parse `specs/<feature>/tdd/test-list.md` 4-column rows into `BehaviorRow(id, description, traces, state, kind-from-section)` in list order, malformed rows error naming the line, in `lib/src/plugins/tdd/services/test_list_reader.dart`
- [x] T003 [P] [U4] [U5] [U6] Implement `cycle_evidence.dart`: `redEvidence(featureDir)` and `greenEvidence(featureDir)` sets via the `split('\n## ')` section parsing pattern from `verify_red_command.dart`; missing log → empty sets, in `lib/src/plugins/tdd/services/cycle_evidence.dart`
- [x] T004 [P] [U7] [U8] [U9] [U10] [U11] Implement `run_state_store.dart`: atomic (temp+rename) save and validating load of `tdd/run-state.json`, corruption error naming the recovery path, concurrent-run refusal when an in-flight marker is held, dropped-marker retention for rows removed from the test list, in `lib/src/plugins/tdd/services/run_state_store.dart` (extends `lib/src/plugins/tdd/models/run_state.dart`)
- [x] T005 [U12] [U13] [U14] [U15] [U16] [U17] [U18] Implement `step_runner.dart`: resolve the zfa entrypoint (`--zfa-bin` override → package-root `bin/zfa.dart` via `Isolate.resolvePackageUri` walk-up), spawn `tdd <step> <behavior-id> --feature <f> --project <dir>` via `Process.run`, parse each step's summary line per contracts/run.md, return `StepResult(step, behaviorId, exitCode, outcome, success, output)`, in `lib/src/plugins/tdd/services/step_runner.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Drive a feature end-to-end (Priority: P1) 🎯 MVP

**Goal**: `zfa tdd run <feature>` walks every behavior through
PENDING → RED → GREEN → DONE via the four steps, in list order, with state
saved after each step.

**Independent Test**: 3-behavior fixture with all-pass fake steps → exit 0,
all DONE in run-state.json, per-step progress lines, red+green entry per
behavior (quickstart.md scenario 3).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [x] T006 [P] [US1] [U1] [U2] [U3] [U4] [U5] [U6] [U7] [U8] Reader/evidence/store tests (fast): 4-column parse with section-derived kind; red/green evidence sets from a synthetic cycle log; save→load round-trip + atomicity, in `test/plugins/tdd/services/test_list_reader_test.dart`, `cycle_evidence_test.dart`, `run_state_store_test.dart`
- [x] T007 [P] [US1] [U12] [U13] [U14] [U15] [U16] [U17] Step-runner test (fast): summary-line parsing per step contract (verify-red `certified=true`, make `outcome=green`, refactor `outcome=clean|refactored`), spawn failure → runner-error, in `test/plugins/tdd/services/step_runner_test.dart`
- [x] T008 [P] [US1] [U19] [U20] [U27] [U28] [U29] Driver test (slow): full drive of a 3-behavior fixture to all-DONE, idempotent re-run reports nothing-to-do exit 0, new behavior appended mid-project is picked up while DONE behaviors stay untouched, in `test/plugins/tdd/run_command_test.dart`
- [x] T009 [P] [US1] [A1] [A2] [A3] Acceptance scenario driving the real CLI end-to-end in `test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart`

### Implementation for User Story 1

- [x] T010 [US1] [U19] [U20] [U21] [U22] [U23] Implement `RunCommand.run()`: `--project`/`--feature`/`--zfa-bin` conventions, load test list + state, reconcile state with evidence (DONE requires red+green), per-behavior loop `pending→gen→verify-red→red→make→green→refactor→done` with markInFlight→save→step→advance→save rhythm, progress line per step, in `lib/src/plugins/tdd/commands/run_command.dart`
- [x] T011 [US1] [U26] [U27] Implement the final summary line `run: feature=<f> result=complete ... done=<n>` and exit 0 exactly on complete-with-evidence, in `lib/src/plugins/tdd/commands/run_command.dart`

**Checkpoint**: US1 fully functional and independently testable; A1–A3 green

---

## Phase 4: User Story 2 - Resume an interrupted run (Priority: P1)

**Goal**: Interrupted runs resume from persisted state: DONE skipped,
incomplete behaviors re-enter at the state-implied step, in-flight re-entry
safe via step idempotency; corrupted state refused with recovery path.

**Independent Test**: Boundary matrix — interrupt after each step of a
2-behavior fixture, resume, assert strictly-less work (progress-line counts)
and correct re-entry step; corrupted JSON → non-zero naming recovery
(quickstart.md scenario 4).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [x] T012 [P] [US2] [U22] [U23] [U9] [U10] Resume tests (slow): seeded states (RED→make re-entry, GREEN→refactor re-entry, in-flight step re-execution), strictly-less-work assertion via fake-step invocation logs, corrupted-state refusal, concurrent-run refusal via in-flight marker, in `test/plugins/tdd/run_command_test.dart`
- [x] T013 [P] [US2] [A4] [A5] [A6] Acceptance scenario for resume and corruption refusal in `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart`

### Implementation for User Story 2

- [x] T014 [US2] [U22] [U23] [U10] Implement resume logic: load→evidence-reconcile→skip DONE→re-enter incomplete at state-implied step; wire `run_state_store.dart` corruption and concurrency guards into the command's start path, in `lib/src/plugins/tdd/commands/run_command.dart`

**Checkpoint**: US1 AND US2 both work independently; A4–A6 green

---

## Phase 5: User Story 3 - Stop honestly on failure (Priority: P1)

**Goal**: Any step failure stops the run immediately: behavior left at last
completed state, failing step+outcome named, later behaviors never started,
resume instructions printed.

**Independent Test**: Failure matrix — gen ownership conflict, verify-red
dishonest, make unexpressible, refactor regression, stubbed step → each
stops non-zero with `stopped_at=<behavior>:<step>` and correct residual
state (quickstart.md scenario 5).

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [x] T015 [P] [US3] [U24] Stop-on-failure tests (slow): the five-failure matrix above, asserting residual state, named step/outcome, and that the third behavior never appears in the fake-step invocation log, in `test/plugins/tdd/run_command_test.dart`
- [x] T016 [P] [US3] [U21] Evidence-beats-state test: state claims DONE but cycle log lacks green entry → behavior re-driven from the evidence-backed state, in `test/plugins/tdd/run_command_test.dart`
- [x] T017 [P] [US3] [A7] [A8] [A9] Acceptance scenario for honest stops in `test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart`

### Implementation for User Story 3

- [x] T018 [US3] [U21] [U24] Implement failure handling: stop on first failed step, report behavior+step+outcome+resume instructions, leave state at last completed step, never mark DONE without both evidence entries, in `lib/src/plugins/tdd/commands/run_command.dart`

**Checkpoint**: US1–US3 all work independently; A7–A9 green

---

## Phase 6: User Story 4 - Progress and machine-readable summary (Priority: P2)

**Goal**: Per-step progress lines plus a final summary line consumable by CI
and corpus orchestration.

**Independent Test**: Contract test pins progress-line and summary-line
formats across complete/stopped/corrupt/concurrent outcomes (spec SC-005).

### Tests for User Story 4 ⚠️ (write first, watch fail)

- [x] T019 [P] [US4] [U25] [U26] [U27] Contract test (slow): progress-line shape `[run] <behavior> <step> -> <outcome>` and final summary `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n> [stopped_at=...]` for every outcome class, in `test/plugins/tdd/run_command_test.dart`
- [x] T020 [P] [US4] [A10] [A11] [A12] Acceptance scenario for the summary contract in `test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart`

### Implementation for User Story 4

- [x] T021 [US4] [U25] [U26] Emit per-step progress lines and the final summary line on every code path including refusals, in `lib/src/plugins/tdd/commands/run_command.dart`

**Checkpoint**: All user stories independently functional; A10–A12 green

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T022 Run `dart analyze` on all touched files and fix findings
- [x] T023 Run `dart test test/plugins/tdd/` (fast) and `dart test --tags slow test/plugins/tdd/` and confirm both green
- [x] T024 Execute quickstart.md scenarios 1–5 verbatim and record results in `specs/049-tdd-run/tdd/` evidence
- [x] T025 File the zuraffa gap found in research (plan writes 4-column test-list rows, gen's parser expects 6) via the bug workflow, link it from `specs/049-tdd-run/tdd/cycle-log.md` notes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — start immediately
- **Foundational (Phase 2)**: T002–T004 parallel; T005 independent; BLOCKS all user stories
- **US1 (Phase 3)**: depends on Phase 2 + T001
- **US2 (Phase 4)**: depends on US1 (T010)
- **US3 (Phase 5)**: depends on US1; independent of US2
- **US4 (Phase 6)**: depends on US1; independent of US2/US3
- **Polish (Phase 7)**: after all stories

### Parallel Opportunities

- T002, T003, T004, T005 in parallel (different files)
- T006, T007, T008, T009 in parallel (different test files)
- T012, T013 in parallel; T015, T016, T017 in parallel; T019, T020 in parallel

## Parallel Example: User Story 1

```bash
# Launch all US1 tests together:
Task: "Reader/evidence/store tests in test/plugins/tdd/services/"
Task: "Step-runner test in test/plugins/tdd/services/step_runner_test.dart"
Task: "Driver test in test/plugins/tdd/run_command_test.dart"
Task: "Acceptance scenario in test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 → foundation ready
2. Phase 3 (US1) → drive-to-done working on fake steps → **STOP and VALIDATE**
3. Phases 4–6 add resume, honest stops, and the machine contract

### Incremental Delivery

US1 delivers a working sequential driver; US2/US3 harden it for reality
(interruption, failure); US4 finalizes the orchestration contract. Real steps
slot in as 047/048 merge — the driver only knows their contracts.

## Notes

- Fake step binaries stand in for unmerged steps; when 047/048 land, the
  slow scenarios should also run against the real steps (add a variant or
  flip the fixture switch — do not fork the assertions).
- `run_state.dart` model exists with advance/markInFlight/toJson/fromJson
  (U30, already covered by `run_state_test.dart`); T004 adds file I/O
  without changing the model's semantics.
- The plan↔gen test-list column mismatch is NOT fixed here (044/041 own
  those commands); T025 files it as a gap per the epic's protocol.
- Behavior markers added by `/speckit.tdd.plan`; no task renumbered, no new
  tasks needed (all 12 acceptance behaviors map onto existing
  scenario/contract tasks).

## Phase 8: TDD remediation (from /speckit.tdd.verify)

- [x] T026 (F1) Strengthen `U23`/`A5` with a discriminating in-flight seed (state PENDING + marker verify-red, dead owner) asserting re-entry at verify-red with zero redundant `gen` invocations — the ignore-the-marker mutant must be caught. Proved by `075aab18` + mutant re-run. DONE in this session.
- [x] T027 (F2) Pin FR-008's read-only guarantee: a driver test snapshotting the fixture's `test/` and `lib/` trees across a full run via `checksumTestAndLib()`. Proved by `075aab18`. DONE in this session.
- [ ] T028 (verification gap) Wire `mutation_test` for the 049 files (`lib/src/plugins/tdd/services/*`, `run_command.dart`) by extending `mutation-test.xml` scope, so the next `/speckit.tdd.verify` measures rather than samples. Prove with `dart run mutation_test` green and the score recorded.
