# Tasks: `zfa tdd corpus` — batch driving, provenance audit, gap ledger

**Input**: Design documents from `/specs/051-corpus-harness/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: MANDATORY (tdd.plan) — spec SC-001..SC-005 demand automated proof.
Every behavior in `tdd/test-list.md` has a test task below, and each
test must be observed failing before its implementation task starts. All
tests are fast tier (in-memory/temp-dir fixtures — no subprocess suites).

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Core models shared across all user stories

- [ ] T001 [P] Implement `CorpusFeatureState` enum (pending/driving/done/stopped/waived/not-ready/dropped), `CorpusFeatureProgress` value object (name, state, gateOutcome, waived), and `WaiverRecord` (reason, actor, when) in `lib/src/plugins/tdd/models/corpus_feature_progress.dart`
- [ ] T002 [P] Implement `GapLedgerEntry` value object (feature, behavior, step, outcome, command, issueLink, timestamp, resolution) in `lib/src/plugins/tdd/models/gap_ledger_entry.dart`
- [ ] T003 [P] Implement `ProvenanceSource` enum (cycle-log/setup/import/carve-out) and `ProvenanceRecord` value object (filePath, source, invocation, feature, timestamp) in `lib/src/plugins/tdd/models/provenance_record.dart`
- [ ] T004 [P] Implement `CarveOutEntry` value object (path, reason, addedBy, addedAt) in `lib/src/plugins/tdd/models/carve_out_entry.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Storage services and corpus runner — everything the commands use

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Implement `CorpusProgressStore` in `lib/src/plugins/tdd/services/corpus_progress_store.dart`: atomic save via temp+rename, load with corruption detection, in-flight marker (concurrency guard via pid liveness), resume point computation, dropped-feature tracking — mirrors `RunStateStore` pattern
- [ ] T006 Implement `GapLedger` in `lib/src/plugins/tdd/services/gap_ledger.dart`: append-only load/save of `gap-ledger.json`, append entry method, resolution entry method, ledger totals computation (total/unresolved/filed/resolved/blocking), atomic writes
- [ ] T007 Implement `CarveOutManifest` in `lib/src/plugins/tdd/services/carve_out_manifest.dart`: load/save `carve-out.json`, lookup method (path → entry), add/remove entry methods
- [ ] T008 Implement `CorpusRunner` in `lib/src/plugins/tdd/services/corpus_runner.dart`: orchestrates per-feature `zfa tdd run` → `zfa tdd verify` via sub-process spawning (using `--project` flag), parses machine-readable summary lines for outcomes, implements STOP-ON-ROADBLOCK (any feature stop halts corpus), records gap ledger entries on stops, handles verify gate evaluation (PASS→done, NOT_ASSESSED→stop+ledger, waiver check), resume-point-aware (skips done/not-ready/dropped features)

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Drive the corpus with resume (Priority: P1) 🎯 MVP

**Goal**: `zfa tdd corpus run` drives features in manifest order, persists progress, resumes on re-run, stops honestly on failures.

**Independent Test**: 3-feature fixture (complete/gap/not-ready) → first run drives feature 1 to done, stops on feature 2 with ledger entry, leaves feature 3 untouched; re-run resumes at feature 2 (quickstart.md scenario 1).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [ ] T009 [P] [US1] [U1] [U2] [U3] [U4] [U5] [U6] Corpus progress store tests (fast): round-trip save/load, in-flight marker concurrency guard (live pid refuses, dead pid allows resume), corruption detection, dropped tracking, in `test/plugins/tdd/services/corpus_progress_store_test.dart`
- [ ] T010 [P] [US1] [U7] [U8] [U9] [U10] [U11] Gap ledger tests (fast): append-only (no edits to past entries), resolution entry appends alongside original, ledger totals computation, atomic write, in `test/plugins/tdd/services/gap_ledger_test.dart`
- [ ] T011 [US1] [U12] [U13] [U18] [U19] [U20] [U21] Corpus runner tests (fast): 3-feature fixture (ready+gap+not-ready) — first run drives feature 1 to done, stops on feature 2 with ledger entry, skips feature 3; second run resumes at feature 2 without re-driving feature 1; concurrent run refusal, in `test/plugins/tdd/services/corpus_runner_test.dart`

### Implementation for User Story 1

- [ ] T012 [US1] [A1] [A2] [A3] [U27] [U28] [U29] Implement `corpus run` subcommand in `lib/src/plugins/tdd/commands/corpus_command.dart`: loads manifest, checks in-flight marker, loads/creates progress, invokes `CorpusRunner`, prints per-feature progress lines and final summary line per `contracts/corpus-run.md`, sets exit codes (0=complete, 1=stopped, 2=runner-error, 3=corrupt-state, 4=concurrent-run)
- [ ] T013 [US1] Register `CorpusCommand` as subcommand of `TddCommand` in `lib/src/commands/tdd_command.dart` (add `addSubcommand(CorpusCommand(plugin))`)

**Checkpoint**: `zfa tdd corpus run` drives features, stops on gaps, resumes correctly

---

## Phase 4: User Story 2 — Per-feature verify gate (Priority: P1)

**Goal**: A feature only counts as corpus-done when verify gate passes or an explicit waiver is recorded; NOT_ASSESSED and every failure stop the run.

**Independent Test**: Fixture matrix over all five gate values — PASS→done, FAIL_SURVIVED→stop+ledger, FAIL_TIMEOUT→stop+ledger, PREFLIGHT_RED→stop+ledger, NOT_ASSESSED→stop+ledger; waiver records visible in progress and report (quickstart.md scenario 2).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [ ] T014 [P] [US2] [A4] [A5] [A6] [U14] [U15] [U16] [U17] Verify gate integration tests in corpus runner (fast): fixture with features for each gate outcome — runner behavior matches spec for each; waiver mechanism test (waived feature marked done with recorded reason), in `test/plugins/tdd/services/corpus_runner_test.dart` (extend T011 file)

### Implementation for User Story 2

- [ ] T015 [US2] [A4] [A5] [A6] [U14] [U15] [U16] [U17] Implement verify gate evaluation in `CorpusRunner`: parse mutation summary line for gate outcome, map to corpus state (PASS→done, any failure→stopped+ledger, NOT_ASSESSED→stopped+ledger with reason), check waiver before stopping, record waiver in progress — all within `lib/src/plugins/tdd/services/corpus_runner.dart` (extend T008)

**Checkpoint**: All five gate outcomes produce correct corpus states and ledger entries

---

## Phase 5: User Story 3 — Provenance audit (Priority: P1)

**Goal**: `zfa tdd corpus audit` attributes every `lib/` file to a zfa invocation or carve-out; unattributed files fail by name.

**Independent Test**: Corpus-driven fixture app → audit attributes 100%; planting one unattributed file fails audit by name (quickstart.md scenario 3).

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [ ] T016 [P] [US3] [A7] [A8] [A9] [U22] [U23] [U24] [U25] [U26] Provenance auditor tests (fast): fixture with cycle-log-generated files, setup-scaffolded files, and carve-out entries — auditor attributes all three sources; planting unattributed file produces non-exit + names file; provenance.json written correctly, in `test/plugins/tdd/services/provenance_auditor_test.dart`
- [ ] T017 [P] [US3] Carve-out manifest tests (fast): load/save round-trip, lookup by path, add/remove entries, empty manifest, in `test/plugins/tdd/services/carve_out_manifest_test.dart`

### Implementation for User Story 3

- [ ] T018 [US3] [A7] [A8] [A9] [U22] [U23] [U24] [U25] [U26] Implement `ProvenanceAuditor` in `lib/src/plugins/tdd/services/provenance_auditor.dart`: scan `lib/` recursively, check cycle-log entries (parse `tdd/cycle-log.md` green entries for file paths), check setup/import provenance, check carve-out manifest; produce per-file attribution report and summary counts; write `provenance.json`
- [ ] T019 [US3] [A7] [A8] [A9] [U30] [U31] Implement `corpus audit` subcommand in `lib/src/plugins/tdd/commands/corpus_command.dart`: invoke `ProvenanceAuditor`, print per-file lines and summary per `contracts/corpus-audit.md`, exit 0 on 100% attribution, exit 1 on unattributed files

**Checkpoint**: `zfa tdd corpus audit` attributes all generated files and fails on unattributed ones

---

## Phase 6: User Story 4 — The gap ledger (Priority: P1)

**Goal**: Every corpus stop appends a complete ledger entry; ledger history survives resumes; final report includes ledger totals.

**Independent Test**: Stop produces complete ledger entry; resumed run that passes the previously-gapped feature appends a resolution entry; final report lists ledger totals and unresolved gaps (quickstart.md scenarios 1 + 4).

### Tests for User Story 4 ⚠️ (write first, watch fail)

- [ ] T020 [P] [US4] [U7] [U8] Gap ledger entry completeness test (fast): stop during corpus run produces entry with all five required fields (feature, behavior, step, outcome, command), in `test/plugins/tdd/services/gap_ledger_test.dart` (extend T010 file)
- [ ] T021 [P] [US4] [U9] [U10] Ledger history survival test (fast): resume run that passes a previously-gapped feature appends resolution entry; original entry unchanged; ledger totals reflect both entries, in `test/plugins/tdd/services/gap_ledger_test.dart` (extend T010 file)

### Implementation for User Story 4

- [ ] T022 [US4] [A3] [U7] [U8] [U9] [U10] [U19] Wire gap ledger into `CorpusRunner` stop path: on every feature stop (run failure or gate failure), call `GapLedger.append(...)` with the complete entry fields — implemented in `lib/src/plugins/tdd/services/corpus_runner.dart` (extend T008); on feature pass after a previous stop, call `GapLedger.appendResolution(...)` — implemented in `lib/src/plugins/tdd/services/gap_ledger.dart` (extend T006)

**Checkpoint**: 100% of stops produce complete ledger entries; ledger history survives resumes

---

## Phase 7: User Story 5 — Corpus status at a glance (Priority: P2)

**Goal**: `zfa tdd corpus status` reports per-state counts, resume point, and ledger totals read-only; machine-readable summary line; exit 0 when all done.

**Independent Test**: Partially driven corpus → status reports correct counts and resume point; CI parses summary line (quickstart.md scenario 4).

### Tests for User Story 5 ⚠️ (write first, watch fail)

- [ ] T023 [P] [US5] [A10] [A11] [U33] [U34] Corpus status contract test (fast): fixture with mixed-state features → summary line matches expected format; exit 0 when all done, non-zero otherwise; machine-readable fields parseable, in `test/plugins/tdd/commands/corpus_command_test.dart`
- [ ] T024 [P] [US5] [A10] [U5] [U6] Status resume point test (fast): status identifies first non-done/non-not-ready/non-dropped feature as resume point; empty progress → resume at first manifest feature, in `test/plugins/tdd/commands/corpus_command_test.dart` (extend T023 file)

### Implementation for User Story 5

- [ ] T025 [US5] [A10] [A11] [U32] [U33] [U34] Implement `corpus status` subcommand in `lib/src/plugins/tdd/commands/corpus_command.dart`: load manifest + progress + ledger, compute per-state counts and resume point, print per-feature status lines and summary per `contracts/corpus-status.md`, exit 0 when all done+gated

**Checkpoint**: `zfa tdd corpus status` reports accurate counts and resume point

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration, edge cases, and end-to-end validation

- [ ] T026 [U28] [U29] [U31] [U33] [U34] Implement machine-readable summary line contract tests for all three subcommands (run/audit/status): verify exact format matches contracts, exit codes match spec, in `test/plugins/tdd/commands/corpus_command_test.dart`
- [ ] T027 [U6] [U21] Implement edge case: manifest edited mid-run (features added/removed) — added features driven on next run, removed features marked dropped, in `test/plugins/tdd/services/corpus_runner_test.dart`
- [ ] T028 Run `dart analyze lib/src/plugins/tdd/commands/corpus_command.dart lib/src/plugins/tdd/models/ lib/src/plugins/tdd/services/corpus_*.dart lib/src/plugins/tdd/services/gap_ledger.dart lib/src/plugins/tdd/services/provenance_auditor.dart lib/src/plugins/tdd/services/carve_out_manifest.dart` — verify zero analysis errors
- [ ] T029 Run full fast test suite for the new files: `dart test test/plugins/tdd/commands/corpus_command_test.dart test/plugins/tdd/services/corpus_progress_store_test.dart test/plugins/tdd/services/corpus_runner_test.dart test/plugins/tdd/services/gap_ledger_test.dart test/plugins/tdd/services/provenance_auditor_test.dart test/plugins/tdd/services/carve_out_manifest_test.dart test/plugins/tdd/models/corpus_feature_progress_test.dart test/plugins/tdd/models/gap_ledger_entry_test.dart test/plugins/tdd/models/provenance_record_test.dart` — all green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately. All 4 model tasks are [P] (parallelizable).
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories. T005-T008 depend on models from T001-T004.
- **User Stories 1-4 (Phase 3-6)**: All depend on Phase 2 completion. US1 (run) is the MVP; US2 (gate) extends the runner; US3 (audit) and US4 (ledger) are independent of each other but both consume Phase 2 services.
- **User Story 5 (Phase 7)**: Depends on Phase 2 completion; reads progress + ledger but does not drive.
- **Polish (Phase 8)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No dependencies on other stories.
- **US2 (P1)**: Extends the runner from US1. Start after US1 implementation (T012-T013).
- **US3 (P1)**: Independent of US1/US2. Can start after Phase 2.
- **US4 (P1)**: Wires ledger into runner from US1. Start after US1 implementation.
- **US5 (P2)**: Independent read-only status. Can start after Phase 2.

### Parallel Opportunities

- **Phase 1**: All 4 model tasks (T001-T004) are [P] — run in parallel.
- **Phase 2**: T005-T007 are [P] — run in parallel (T008 depends on them).
- **Phase 3 tests**: T009-T010 are [P] — run in parallel.
- **Phase 5 tests**: T016-T017 are [P] — run in parallel.
- **Phase 6 tests**: T020-T021 are [P] — run in parallel.
- **Phase 7 tests**: T023-T024 are [P] — run in parallel.
- **Cross-story**: US3 (audit) and US5 (status) are independent and can be implemented in parallel.

---

## Parallel Example: User Story 1

```bash
# Launch parallel tests for US1:
Task: T009 — corpus_progress_store_test.dart (fast)
Task: T010 — gap_ledger_test.dart (fast)

# Then implement sequentially (dependencies):
Task: T012 — corpus_command.dart (run subcommand)
Task: T013 — tdd_command.dart (register CorpusCommand)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Models (T001-T004 in parallel)
2. Complete Phase 2: Services (T005-T008)
3. Complete Phase 3: US1 — `corpus run` with resume + gap recording (T009-T013)
4. **STOP and VALIDATE**: Run the 3-feature fixture scenario
5. The run command already records gap ledger entries (US4 is partially done via T008)

### Incremental Delivery

1. Phase 1+2 → Foundation ready
2. Phase 3 (US1) → `corpus run` works → MVP!
3. Phase 4 (US2) → verify gate fully wired
4. Phase 5 (US3) → `corpus audit` works
5. Phase 6 (US4) → gap ledger complete + wired
6. Phase 7 (US5) → `corpus status` works
7. Phase 8 → Polish + all tests green

### Parallel Team Strategy

With multiple developers after Phase 2:
- Developer A: US1 (run) + US2 (gate) — sequential, same code path
- Developer B: US3 (audit) — independent service
- Developer C: US5 (status) — independent read-only command
- US4 (ledger) is wired into the runner by Developer A

---

## Notes

- [P] tasks = different files, no dependencies — run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story phase has tests FIRST (write red), then implementation (make green)
- The corpus runner (T008) is the largest task — it orchestrates the core loop
- Verify gate evaluation (T015) extends the runner, not a separate service
- Gap ledger wiring (T022) connects existing ledger service to runner stops
- All summary lines follow the machine-readable `key=value` contract format

---

## Phase 9: TDD remediation

**Verdict: FAIL.** The feature is not done until blocking findings T030-T032 are cleared.

- [ ] T030 [HIGH] Write acceptance tests for A1-A3 (corpus run drives features, resumes, stops on failure) — create `test/plugins/tdd/scenarios/sc_019_corpus_run_e2e_test.dart` with a 3-feature fixture exercising the full run→stop→resume cycle via `Process.run`. Verify: `dart test test/plugins/tdd/scenarios/sc_019_corpus_run_e2e_test.dart` passes.
- [ ] T031 [HIGH] Write acceptance tests for A4-A6 (verify gate outcomes + waiver) — extend `corpus_command_test.dart` with gate outcome matrix tests (PASS/FAIL_SURVIVED/FAIL_TIMEOUT/PREFLIGHT_RED/NOT_ASSESSED/waived). Verify: `dart test test/plugins/tdd/commands/corpus_command_test.dart` passes.
- [ ] T032 [HIGH] Write acceptance test for A9 (carve-out removal audit) — add test to `corpus_command_test.dart` that creates a carve-out, runs audit (pass), removes carve-out, re-runs audit (fail). Verify: test passes.
- [ ] T033 [HIGH] Write unit test for U17 (waived feature skips gate failure) — add test to `corpus_runner_test.dart` with a zfa that returns FAIL_SURVIVED but has a waiver in progress. Verify: feature marked done with waiver record.
- [ ] T034 [MED] Write unit tests for U27, U30-U31 (command format contracts) — add tests verifying exact per-file/summary line formats match contracts/corpus-run.md and contracts/corpus-audit.md.
- [ ] T035 [MED] Commit all source and test files — `git add` the new files and commit with a message referencing spec 051. This enables git-history-based test-first evidence for future audits.
