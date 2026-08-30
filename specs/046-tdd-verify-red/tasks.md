# Tasks: `zfa tdd verify-red`

**Input**: Design documents from `/specs/046-tdd-verify-red/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/verify-red.md

**Tests**: MANDATORY (tdd.plan) — this feature IS a TDD-loop gate; spec
SC-001..SC-005 demand automated proof. Every behavior in
`tdd/test-list.md` has a test task below, and each test must be observed
failing before its implementation task starts.

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Test fixture scaffolding shared by all stories

- [ ] T001 Create fixture helper that builds a temp project with `specs/<feature>/tdd/artifacts.json`, `.specify/memory/tdd-profile.md`, and a synthetic test file, in `test/plugins/tdd/helpers/tdd_fixture.dart` (mirror `Directory.systemTemp` + `CliRunner(exitOnCompletion: false)` conventions from `test/plugins/tdd/tdd_command_smoke_test.dart`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models and services every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] [U15] [U16] Widen `FailureClass` with `skipped` and `runnerError`, and extend `CycleLogEntry` with `sourceCriterion`, `testPath`, `timestamp` (ISO-8601 UTC) updating `toMarkdown()` to emit the fixed 8-field entry from contracts/verify-red.md, in `lib/src/plugins/tdd/models/cycle_entry.dart`
- [ ] T003 [P] [U1] [U2] [U3] [U4] [U5] [U6] [U7] [U8] [U9] [U10] [U11] [U12] [U13] [U14] Add `RedClassification` enum (`assertion`, `compileError`, `loadError`, `skipped`, `unexpectedGreen`, `runnerError`) and `RunRecord` value object (`command`, `exitCode`, `output`, `startedProcess`, `testCount`) in `lib/src/plugins/tdd/models/red_classification.dart`
- [ ] T004 [U1] [U2] [U3] [U4] [U5] [U6] [U7] [U8] [U9] [U10] Implement `red_classifier.dart` pure function `RedClassification classify(RunRecord)` applying the ordered rules from research.md Decision 3 (runner-error → load-error → compile-error → skipped → unexpected-green → assertion; `testCount != 1` forces runnerError except for load/compile), in `lib/src/plugins/tdd/services/red_classifier.dart`
- [ ] T005 [U11] [U12] [U13] [U14] Implement `runner.dart` service: load `TddProfile` from `.specify/memory/tdd-profile.md`, `resolveSingle(file:, name:)`, execute via `Process.run` with working directory, capture exit code + combined output + process-start success, return `RunRecord`, in `lib/src/plugins/tdd/services/runner.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Verify an honestly-red behavior (Priority: P1) 🎯 MVP

**Goal**: `zfa tdd verify-red <id>` certifies honest red: classification
`assertion`, 8-field cycle-log entry, exit 0, zero writes outside the log.

**Independent Test**: Fixture with a `gen`-style red behavior → command exits
0, summary line `certified=true`, cycle log gains a complete entry,
`test/`+`lib/` checksums unchanged (quickstart.md scenarios 1, 2, 4).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [ ] T006 [P] [US1] [U1] Classifier test: canned runner outputs for assertion failures (dart + flutter shapes) classify as `assertion` in `test/plugins/tdd/red_classifier_test.dart`
- [ ] T007 [P] [US1] [U11] [U12] [U13] [U14] Runner test: profile substitution and `RunRecord` capture against a tiny real temp `dart test` project in `test/plugins/tdd/runner_test.dart`
- [ ] T008 [P] [US1] [U23] [U25] Command contract test: certified run exits 0, appends a complete 8-field entry matching contracts/verify-red.md, prints the summary line, and leaves `test/`+`lib/` checksums unchanged in `test/plugins/tdd/verify_red_command_test.dart`
- [ ] T021 [P] [US1] [A1] [A2] [A3] Acceptance scenario test driving the real CLI entry end-to-end for the certified-honest-red path (stays red until US1 completes) in `test/plugins/tdd/scenarios/sc_001_certifies_honest_red_test.dart`

### Implementation for User Story 1

- [ ] T009 [US1] [U23] [U27] Implement `VerifyRedCommand.run()`: explicit-id resolution via `ArtifactRegistry.findRecord`, load profile (misfire-stop when missing/unreadable), run via `runner.dart`, classify via `red_classifier.dart`, on `assertion` append `CycleLogEntry(kind: red)` via `CycleLog` and print summary line per contracts/verify-red.md, in `lib/src/plugins/tdd/commands/verify_red_command.dart`
- [ ] T010 [US1] [U24] Wire stderr error reporting and remediation hints for non-assertion outcomes, exit non-zero without log writes, in `lib/src/plugins/tdd/commands/verify_red_command.dart`

**Checkpoint**: US1 fully functional and independently testable; A1–A3 green

---

## Phase 4: User Story 2 - Reject dishonest red (Priority: P1)

**Goal**: Every dishonest class exits non-zero with a named classification
and writes no evidence.

**Independent Test**: Fixture matrix (compile-error, load-error, skipped,
unexpected-green, runner-error) → non-zero exits, named classes,
cycle log byte-identical before/after (quickstart.md scenario 3).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [ ] T011 [P] [US2] [U2] [U3] [U4] [U5] [U6] [U7] [U8] [U9] [U10] Classifier fixture-matrix test covering all five dishonest classes including blended-run (`testCount != 1`) and process-start failure, in `test/plugins/tdd/red_classifier_test.dart`
- [ ] T012 [P] [US2] [U24] Command rejection test: each dishonest fixture exits non-zero, names the class on stderr, and leaves `cycle-log.md` byte-identical, in `test/plugins/tdd/verify_red_command_test.dart`
- [ ] T022 [P] [US2] [A4] [A5] [A6] [A7] [A8] Acceptance scenario test driving the real CLI for all five dishonest classes (stays red until US2 completes) in `test/plugins/tdd/scenarios/sc_002_rejects_dishonest_red_test.dart`

### Implementation for User Story 2

- [ ] T013 [US2] [A4] [A5] [A6] [A7] [A8] Implement per-class stderr messages with remediation hints (fix compile error; restore missing file; un-skip test; run `make` for unexpected-green; check runner/tooling for runner-error) in `lib/src/plugins/tdd/commands/verify_red_command.dart`

**Checkpoint**: US1 AND US2 both work independently; A4–A8 green

---

## Phase 5: User Story 3 - Unambiguous target resolution (Priority: P2)

**Goal**: Deterministic target selection: explicit id, single-candidate
inference, or a named error.

**Independent Test**: quickstart.md scenario 5 plus unknown-id and
missing-artifacts cases from spec US3.

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [ ] T014 [P] [US3] [U17] [U18] [U19] [U20] [U21] [U22] Resolution tests: unknown id errors before any run; no-arg with exactly one uncertified gen'd behavior selects it; no-arg with multiple candidates lists them and exits non-zero; id without registry artifacts instructs `zfa tdd gen` first, in `test/plugins/tdd/verify_red_command_test.dart`
- [ ] T023 [P] [US3] [A9] [A10] [A11] [A12] Acceptance scenario test driving the real CLI for all four resolution rules (stays red until US3 completes) in `test/plugins/tdd/scenarios/sc_003_target_resolution_test.dart`

### Implementation for User Story 3

- [ ] T015 [US3] [U17] [U18] [U19] [U20] [U21] [U22] Implement no-arg inference: load registry records, subtract behaviors with existing red entries in `cycle-log.md`, require exactly one candidate; `--feature` flag handling consistent with `gen_command.dart`, in `lib/src/plugins/tdd/commands/verify_red_command.dart`

**Checkpoint**: US1–US3 all independently functional; A9–A12 green

---

## Phase 6: User Story 4 - Machine-readable result contract (Priority: P2)

**Goal**: Stable summary line + exit-code contract consumable by
`zfa tdd run` and CI without parsing prose.

**Independent Test**: Contract test asserts exact summary-line shape for
certified and rejected runs (spec SC-005).

### Tests for User Story 4 ⚠️ (write first, watch fail)

- [ ] T016 [P] [US4] [U26] Contract test pinning the summary-line format `verify-red: behavior=<id> classification=<class> certified=<bool> feature=<feature>` for both outcomes, in `test/plugins/tdd/verify_red_command_test.dart`
- [ ] T024 [P] [US4] [A13] [A14] Acceptance scenario test asserting exit-code semantics (0 exactly on certification) and the final-line summary contract through the real CLI, in `test/plugins/tdd/scenarios/sc_004_summary_contract_test.dart`

### Implementation for User Story 4

- [ ] T017 [US4] [U26] Emit the summary line as the final stdout line on every code path (certified, rejected, resolution error) in `lib/src/plugins/tdd/commands/verify_red_command.dart`

**Checkpoint**: All user stories independently functional; A13–A14 green

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T018 Run `dart analyze` on all touched files and fix findings
- [ ] T019 Run scoped suite `dart test test/plugins/tdd/` and confirm green (after the pre-existing 044 failures noted in `tdd/cycle-log.md` baseline are fixed or quarantined)
- [ ] T020 Execute quickstart.md scenarios 1–5 verbatim and record results in `specs/046-tdd-verify-red/tdd/` evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — start immediately
- **Foundational (Phase 2)**: depends on T001; BLOCKS all user stories
- **US1 (Phase 3)**: depends on Phase 2 (T002–T005)
- **US2 (Phase 4)**: depends on US1 command skeleton (T009–T010)
- **US3 (Phase 5)**: depends on US1 command skeleton; independent of US2
- **US4 (Phase 6)**: depends on US1; independent of US2/US3
- **Polish (Phase 7)**: after all stories

### Parallel Opportunities

- T002, T003 in parallel (different files); T004 after T003; T005 after T003
- T006, T007, T008, T021 in parallel (different test files)
- T011, T012, T022 in parallel; T014+T023 and T016+T024 in parallel pairs

## Parallel Example: User Story 1

```bash
# Launch all US1 tests together:
Task: "Classifier test: assertion shapes in test/plugins/tdd/red_classifier_test.dart"
Task: "Runner test in test/plugins/tdd/runner_test.dart"
Task: "Command contract test in test/plugins/tdd/verify_red_command_test.dart"
Task: "Acceptance scenario in test/plugins/tdd/scenarios/sc_001_certifies_honest_red_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 → foundation ready
2. Phase 3 (US1) → certified-happy-path working → **STOP and VALIDATE**
3. Phases 4–6 harden the gate without changing the happy path

### Incremental Delivery

Each story lands behind the same command surface; rejections (US2),
resolution (US3), and the machine contract (US4) are separable increments
that never regress US1's green certification path.

## Notes

- All tests are fast unit tier (no `slow` tag) per `dart_test.yaml` presets.
- The command mutates exactly one file: the `cycle-log.md` append — and only
  on certification.
- Misfire-stop: any internal step that cannot complete stops the command
  non-zero with a clear message (spec FR-010).
- Acceptance scenario tasks T021–T024 were appended by `/speckit.tdd.plan`
  (ids continue the sequence; no existing task was renumbered).
