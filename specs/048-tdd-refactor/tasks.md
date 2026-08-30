# Tasks: `zfa tdd refactor`

**Input**: Design documents from `/specs/048-tdd-refactor/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refactor.md

**Tests**: MANDATORY (tdd.plan) — this feature is a TDD-loop step; spec
SC-001..SC-006 demand automated proof. Every behavior in `tdd/test-list.md`
has a test task below, and each test must be observed failing before its
implementation task starts. Service tests are fast tier; command/scenario
tests are `@Tags(['slow'])` subprocess tests mirroring
`verify_red_command_test.dart`.

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Fixture extensions shared by all stories

- [ ] T001 Extend `TddFixture` in `test/plugins/tdd/helpers/tdd_fixture.dart` with: a green-suite seed (one passing test, no failures), a red-suite seed (one failing test), a malformed-`lib/` file seed (formatter/fixable violations), and a fake tool runner hook so `refactor_passes` can be tested without real subprocesses

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models and shared services every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] [U2] [U8] Add `RefactorOutcome` enum (clean, refactored, not-green, regression, runner-error) and `RefactorAction` value object (name, command, exitCode, filesChanged, output) per data-model.md in `lib/src/plugins/tdd/models/refactor_action.dart`
- [ ] T003 [P] [U8] [U9] [U10] Extend `CycleLogEntry` in `lib/src/plugins/tdd/models/cycle_entry.dart`: add `CycleEntryKind.refactor`, relax the assert to `kind != red || classification != null`, fix the hardcoded red/green label in `toMarkdown()` (existing red/green rendering stays byte-compatible), add `refactorActions` rendered as the `actions:` block per contracts/refactor.md
- [ ] T004 [P] [U6] [U7] Create `tree_snapshot.dart`: generalize `verify_red_command.dart`'s private `_ReadOnlyTreeSnapshot` (path → `file:<sha256>`/`directory`/`link:<target>`, `changedPaths` diff) into a shared service in `lib/src/plugins/tdd/services/tree_snapshot.dart` (verify_red keeps its private copy working; no behavior change there)
- [ ] T005 [U11] [U12] Extend `SingleTestRunner` in `lib/src/plugins/tdd/services/runner.dart` with `loadSuiteTemplate()` (the profile `suite` key) and `runSuite()` returning exit code + combined output (coordinate: 047 plans the same extension — whichever lands first owns it, the other rebases)
- [ ] T006 [U1] [U2] [U3] [U4] [U5] Implement `refactor_passes.dart`: the fixed pass registry in order (`zfa build`, `dart format lib/`, `dart fix --apply lib/`), each pass executed via an injectable process executor, capturing a `RefactorAction` with its `filesChanged` from a per-pass tree-snapshot diff, stopping remaining passes on first failure, in `lib/src/plugins/tdd/services/refactor_passes.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Green-suite preflight gate (Priority: P1) 🎯 MVP

**Goal**: `zfa tdd refactor` runs the profile suite first; any red (or
unrunnable) suite refuses with named failures and zero file modifications.

**Independent Test**: Red-suite fixture → non-zero `not-green` naming the
failing test; broken-runner fixture → non-zero `runner-error`; both modify
no files (quickstart.md scenario 4).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [ ] T007 [P] [US1] [U14] [U15] Preflight tests (slow): red-suite fixture → exit non-zero, outcome `not-green`, failing test named, zero project files changed; broken-runner fixture → `runner-error`, in `test/plugins/tdd/refactor_command_test.dart`
- [ ] T008 [P] [US1] [A2] [A3] Acceptance scenario for red-suite refusal and unrunnable-suite refusal through the real CLI in `test/plugins/tdd/scenarios/sc_010_refuses_red_suite_test.dart`

### Implementation for User Story 1

- [ ] T009 [US1] [U13] [U14] [U15] [U22] Implement `RefactorCommand.run()`: mirror post-`43841d0c` `verify_red_command.dart` conventions (`--project` resolution, `--feature`, `print()` summary, `exitCode` assignment, misfire-stop try/catch); run the profile suite via `runner.dart` as absolute preflight; refusal paths name failing tests and point to `zfa tdd make`, in `lib/src/plugins/tdd/commands/refactor_command.dart`

**Checkpoint**: US1 fully functional and independently testable; A2–A3 green

---

## Phase 4: User Story 2 - Tool-driven refactors only (Priority: P1)

**Goal**: The pass registry executes build/format/fix as recorded tool
actions; `test/` stays byte-identical; every `lib/` change is attributed to
a recorded pass.

**Independent Test**: Malformed-`lib/` fixture → passes apply, `test/`
checksums unchanged, every changed `lib/` path appears in some action's
`filesChanged` (quickstart.md scenario 5).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [ ] T010 [P] [US2] [U1] [U2] [U3] [U4] [U5] Pass-registry tests (fast): fixed order build→format→fix, per-pass capture, first-failure stops remaining passes, filesChanged attributed from per-pass snapshot diff, in `test/plugins/tdd/services/refactor_passes_test.dart`
- [ ] T011 [P] [US2] [U6] [U7] Tree-snapshot tests (fast): file/dir/link hashing, symmetric changedPaths diff, in `test/plugins/tdd/services/tree_snapshot_test.dart`
- [ ] T012 [P] [US2] [U16] [U17] Command test (slow): malformed-`lib/` fixture → actions recorded with commands; `test/` byte-identical; unattributed-`lib/` violation is a hard failure, in `test/plugins/tdd/refactor_command_test.dart`
- [ ] T013 [P] [US2] [A4] [A5] [A6] Acceptance scenario for tool-only changes + test immutability in `test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart`

### Implementation for User Story 2

- [ ] T014 [US2] [U16] [U17] Wire the pass registry into the command: pre/post `test/` snapshot must be identical (hard failure otherwise), pre/post `lib/` diff must be fully covered by recorded actions (hard failure otherwise), in `lib/src/plugins/tdd/commands/refactor_command.dart`

**Checkpoint**: US1 AND US2 both work independently; A4–A6 green

---

## Phase 5: User Story 3 - Post-refactor re-proof and evidence (Priority: P1)

**Goal**: After any applied pass, the suite re-runs; green → evidence entry
with actions; regression → non-zero, named tests, no evidence; nothing to
do → honest `clean` no-op.

**Independent Test**: Three fixtures: (a) passes change files, suite stays
green → `refactored` + entry; (b) a pass breaks a test → `regression`, no
entry; (c) nothing to change → `clean`, no fabricated actions.

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [ ] T015 [P] [US3] [U18] [U19] [U20] Re-proof tests (slow): all three fixtures above, asserting evidence content per contracts/refactor.md, in `test/plugins/tdd/refactor_command_test.dart`
- [ ] T016 [P] [US3] [A1] [A7] [A8] [A9] Acceptance scenario for green-preflight pass-through, re-proof, regression naming, and the clean no-op in `test/plugins/tdd/scenarios/sc_012_reproves_green_test.dart`

### Implementation for User Story 3

- [ ] T017 [US3] [U18] [U19] [U20] Implement post-pass suite re-run via the profile, regression naming on stderr, green-evidence append (refactor entry with actions block; explicit no-op marker for `clean`), in `lib/src/plugins/tdd/commands/refactor_command.dart`

**Checkpoint**: US1–US3 all work independently; A1, A7–A9 green

---

## Phase 6: User Story 4 - Machine-readable result contract (Priority: P2)

**Goal**: Stable summary line + exit-code contract for `zfa tdd run` and CI.

**Independent Test**: Contract test pins the summary format across all five
outcomes (spec SC-006).

### Tests for User Story 4 ⚠️ (write first, watch fail)

- [ ] T018 [P] [US4] [U21] [A10] [A11] Summary contract test: every outcome produces the final-line format `refactor: feature=<f> outcome=<o> applied=<n>` and exit 0 exactly on `clean`/`refactored`, in `test/plugins/tdd/refactor_command_test.dart`

### Implementation for User Story 4

- [ ] T019 [US4] [U21] Emit the summary line as the final stdout line on every code path including preflight refusal and misfire, in `lib/src/plugins/tdd/commands/refactor_command.dart`

**Checkpoint**: All user stories independently functional; A10–A11 green

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T020 Run `dart analyze` on all touched files and fix findings
- [ ] T021 Run `dart test test/plugins/tdd/` (fast) and `dart test --tags slow test/plugins/tdd/` and confirm both green
- [ ] T022 Execute quickstart.md scenarios 1–5 verbatim and record results in `specs/048-tdd-refactor/tdd/` evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — start immediately
- **Foundational (Phase 2)**: T002–T004 parallel; T005, T006 after T002/T004; BLOCKS all user stories
- **US1 (Phase 3)**: depends on T005 + command skeleton
- **US2 (Phase 4)**: depends on US1 (T009) + T006
- **US3 (Phase 5)**: depends on US2 (T014)
- **US4 (Phase 6)**: depends on US1; independent of US2/US3
- **Polish (Phase 7)**: after all stories

### Parallel Opportunities

- T002, T003, T004 in parallel; T005+T006 after
- T007, T008 in parallel; T010, T011, T012, T013 in parallel; T015, T016 in parallel

## Parallel Example: User Story 2

```bash
# Launch all US2 tests together:
Task: "Pass-registry tests in test/plugins/tdd/services/refactor_passes_test.dart"
Task: "Tree-snapshot tests in test/plugins/tdd/services/tree_snapshot_test.dart"
Task: "Command test in test/plugins/tdd/refactor_command_test.dart"
Task: "Acceptance scenario in test/plugins/tdd/scenarios/sc_011_tool_only_and_test_immutable_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 → foundation ready
2. Phase 3 (US1) → the preflight gate alone delivers value (a safe no-op
   guardian) → **STOP and VALIDATE**
3. Phases 4–6 add the passes, re-proof, and machine contract

### Incremental Delivery

US1 is a working refusal-only command; US2 adds actions behind the same gate;
US3 adds evidence; US4 hardens the contract. Each increment keeps the suite
green and the command usable.

## Notes

- Coordinate with 047-tdd-make on the `runner.dart` suite extension (T005):
  identical change; whichever merges first owns it.
- `CycleLogEntry` changes (T003) must keep existing red/green entries
  byte-compatible in rendering (U10, already covered by existing tests).
- Misfire-stop: any tool action that fails stops remaining passes, and the
  suite is re-run to report the resulting safety state (spec FR-010).
- Behavior markers added by `/speckit.tdd.plan`; no task renumbered, no new
  tasks needed (all 11 acceptance behaviors map onto existing
  scenario/contract tasks).
