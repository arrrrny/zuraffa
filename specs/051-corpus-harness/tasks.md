# Tasks: `zfa tdd corpus` — batch loop driving, provenance audit, gap ledger

**Input**: Design documents from `/specs/051-corpus-harness/` (spec.md,
plan.md, research.md, data-model.md, contracts/corpus-harness.md,
quickstart.md)

**Prerequisites**: plan.md (required), spec.md (required), research.md,
data-model.md, contracts/

**Tests**: REQUIRED — the tdd extension drives this feature test-first
(`specs/051-corpus-harness/tdd/test-list.md` is the behavior contract;
every behavior's test is written and RED before its implementation task
runs).

**Organization**: Tasks grouped by user story (spec.md US1–US5) with a
foundational phase for the shared stores the P1 stories all consume.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Include exact file paths in descriptions

## Path Conventions

Repo-root package (matches plan.md): implementation under
`lib/src/plugins/tdd/{commands,models,services}/`, fast-tier tests under
`test/plugins/tdd/{commands,models,services}/`, slow-tier scenarios under
`test/plugins/tdd/scenarios/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: register the command family so the CLI surface exists

- [ ] T001 Register `CorpusCommand` parent with `run`/`status`/`audit`
  subcommands in `lib/src/plugins/tdd/commands/corpus_command.dart` +
  wire into `lib/src/commands/tdd_command.dart` (each subcommand file
  created as a usage-printing skeleton); update
  `test/plugins/tdd/tdd_command_smoke_test.dart` to expect `corpus` and
  its three subcommands in `zfa tdd --help`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the models + stores + spawner every P1 story consumes

- [ ] T002 [P] Implement `CorpusFeature` + `CorpusManifest` (fromJson,
  corrupt→`CorpusManifestException` naming recovery) in
  `lib/src/plugins/tdd/models/corpus_manifest.dart`
- [ ] T003 [P] Implement `FeatureCorpusState`, `FeatureProgress`,
  `CorpusWaiver`, `CorpusProgress` (in-flight marker, dropped list,
  toJson/fromJson) in `lib/src/plugins/tdd/models/corpus_progress.dart`
- [ ] T004 [P] Implement `GapLedgerEntry` (+ resolution entries, status
  tokens, totals helper) in
  `lib/src/plugins/tdd/models/corpus_ledger.dart`
- [ ] T005 [P] Implement `CorpusManifestStore.read` (manifest +
  carve-out + waivers readers, `.zfa/` path constants) in
  `lib/src/plugins/tdd/services/corpus_manifest_store.dart`
- [ ] T006 [P] Implement `CorpusProgressStore` (atomic temp+rename save,
  load with corruption gate, pid in-flight refusal, dropped marks) in
  `lib/src/plugins/tdd/services/corpus_progress_store.dart`
- [ ] T007 [P] Implement `GapLedgerStore` (load/append with monotonic
  ids, atomic rename) in
  `lib/src/plugins/tdd/services/gap_ledger_store.dart`
- [ ] T008 [P] Implement `CorpusStepRunner` (spawn `tdd run`/`tdd
  verify` via `--zfa-bin` or `dart bin/zfa.dart`, injectable spawner,
  machine-line parsing: run `result=`/`stopped_at=`, verify `gate=`) in
  `lib/src/plugins/tdd/services/corpus_step_runner.dart`
- [ ] T009 [P] Fast-tier model/store/runner tests in
  `test/plugins/tdd/models/corpus_models_test.dart`,
  `test/plugins/tdd/services/corpus_manifest_store_test.dart`,
  `test/plugins/tdd/services/corpus_progress_store_test.dart`,
  `test/plugins/tdd/services/gap_ledger_store_test.dart`,
  `test/plugins/tdd/services/corpus_step_runner_test.dart`

**Checkpoint**: stores + spawner green; user story phases can begin.

---

## Phase 3: User Story 1 — Drive the corpus with resume (P1) 🎯 MVP

**Goal**: `zfa tdd corpus run` drives every `ready` manifest feature
through run→verify in manifest order, persists progress after each
feature, resumes from the first incomplete feature, and honors
STOP-ON-ROADBLOCK.

**Independent Test**: the 3-feature fixture (complete / gap / not-ready)
drives f1 to done, stops on f2 with a ledger entry, never spawns f3;
re-run after the fix resumes at f2 with 0 duplicate f1 invocations
(SC-001).

### Implementation for User Story 1

- [ ] T010 [US1] Implement the driving loop in
  `lib/src/plugins/tdd/commands/corpus_run_command.dart`: manifest
  read → progress load → concurrent refusal → per-feature
  mark-driving → spawn run → spawn verify → gate → persist, with the
  `corpus:` summary line and exit codes 0/1/2/3/4 per
  contracts/corpus-harness.md
- [ ] T011 [US1] Resume semantics: skip `done`/`waived` features, never
  re-drive them; not-ready features skipped and reported (never
  spawned); features removed from the manifest marked `dropped`
- [ ] T012 [US1] STOP-ON-ROADBLOCK: any run/verify failure stops the
  corpus non-zero, appends the FR-007 ledger entry, and no later
  feature starts
- [ ] T013 [P] [US1] Command tests (in-process CliRunner + injected
  fake spawner) in `test/plugins/tdd/commands/corpus_run_command_test.dart`

**Checkpoint**: the US1 fixture scenario passes end-to-end.

---

## Phase 4: User Story 2 — Per-feature verify gate (P1)

**Goal**: a feature counts as corpus-done only on a passing gate or an
explicit recorded waiver; every other outcome stops and ledger — never
silently absorbed.

**Independent Test**: the fixture matrix over all five
`MutationGateDecision` labels — pass→done, the three failures and
not_assessed→stopped+ledger; a waiver covering the exact outcome→waived
with reason+actor+at visible; a waiver for a different outcome does not
absorb (SC-002).

- [ ] T014 [US2] Gate evaluation + waiver honoring in
  `lib/src/plugins/tdd/commands/corpus_run_command.dart` (waiver read
  from `.zfa/corpus/waivers.json`, exact gate match only, waiver copied
  into progress, surfaced in the final report)
- [ ] T015 [P] [US2] Gate-matrix + waiver tests in
  `test/plugins/tdd/commands/corpus_run_command_test.dart`

**Checkpoint**: all five gate values honored; 0 silent absorptions.

---

## Phase 5: User Story 4 — The gap ledger (P1)

**Goal**: every stop lands in the append-only ledger with all six
fields; resolutions are new entries; the final report carries ledger
totals and names unresolved blocking gaps.

**Independent Test**: fixture stop → complete entry; resume+pass → old
entry untouched, resolution entry appended; report totals
found/filed/merged/blocking correct; blocking gaps named (SC-004).

- [ ] T016 [US4] Resolution entries + ledger totals + blocking-gap
  listing in the run/status final report in
  `lib/src/plugins/tdd/commands/corpus_run_command.dart` and
  `lib/src/plugins/tdd/models/corpus_ledger.dart`
- [ ] T017 [P] [US4] Ledger completeness + append-only-history tests in
  `test/plugins/tdd/commands/corpus_run_command_test.dart` and
  `test/plugins/tdd/services/gap_ledger_store_test.dart`

**Checkpoint**: ledger history survives resumes with 0 edits.

---

## Phase 6: User Story 3 — Provenance audit (P1)

**Goal**: `zfa tdd corpus audit` attributes every `lib/` file to a
recorded zfa invocation or carve-out entry; unattributed files fail by
name; machine report + human summary.

**Independent Test**: fixture app with attributed + carve-out +
provenance files audits 100%; planting one unattributed file fails the
audit by name in 100% of runs; removing a carve-out entry flips its file
to unattributed (SC-003, US3.AC3).

- [ ] T018 [US3] Implement `ProvenanceScanner` (lib/ walk, artifacts
  registries, cycle-log refactor `changed:` lists, `.zfa/provenance/*`
  records, carve-out manifest, POSIX-relative normalization) in
  `lib/src/plugins/tdd/services/provenance_scanner.dart`
- [ ] T019 [US3] Implement `zfa tdd corpus audit` in
  `lib/src/plugins/tdd/commands/corpus_audit_command.dart` (report
  JSON at `.zfa/corpus/audit-report.json`, `audit:` summary line,
  exit 0/1/2)
- [ ] T020 [P] [US3] Scanner + command tests (planted unattributed file,
  carve-out removal) in
  `test/plugins/tdd/services/provenance_scanner_test.dart` and
  `test/plugins/tdd/commands/corpus_audit_command_test.dart`

**Checkpoint**: audit is the epic's checkable proof artifact.

---

## Phase 7: User Story 5 — Corpus status at a glance (P2)

**Goal**: read-only status with per-state counts, resume point, ledger
totals, and the stable `corpus:` summary line; exit 0 exactly when all
manifest features are done+gated/waived.

**Independent Test**: status on a partially driven corpus reports
counts + `resume_at` changing nothing; CI contract test pins the line
shape and exit codes (SC-005).

- [ ] T021 [US5] Implement `zfa tdd corpus status` in
  `lib/src/plugins/tdd/commands/corpus_status_command.dart` (read-only
  aggregation, per-state counts, resume point, ledger totals,
  `result=complete|incomplete` semantics)
- [ ] T022 [P] [US5] Status contract tests in
  `test/plugins/tdd/commands/corpus_status_command_test.dart`

**Checkpoint**: CI can consume corpus state without prose scraping.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T023 Slow-tier e2e scenario (real sub-process fake zfa: drive →
  stop → ledger → fix → resume with 0 duplicate invocations;
  concurrent-run refusal) in
  `test/plugins/tdd/scenarios/corpus_harness_scenario_test.dart`
- [ ] T024 Run quickstart.md scenarios 1–4 against a scratch fixture
  app; record outcomes
- [ ] T025 `dart format` + `dart analyze` (0 issues) + full chunked
  test run (`tools/run_tests_chunked.sh`); fix any drift
- [ ] T026 Verify tdd artifacts complete (test-list behaviors all
  PROVEN, cycle-log evidence, verification.md) and commit history clean

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Phase 1 (command skeleton);
  BLOCKS all user stories.
- **US1 (Phase 3)**: depends on Phase 2. MVP.
- **US2 (Phase 4)**: depends on Phase 3 (the gate is evaluated inside
  the driving loop).
- **US4 (Phase 5)**: depends on Phase 3 (stops already ledger; adds
  resolutions + totals).
- **US3 (Phase 6)**: depends on Phase 2 only (audit is independent of
  driving).
- **US5 (Phase 7)**: depends on Phases 3–5 (status aggregates their
  state).
- **Polish (Phase 8)**: depends on all stories.

### User Story Dependencies

- US1 → US2 → US4 (gate and ledger extend the driving loop); US3
  independent after Foundational; US5 last.
- Test-first: every behavior's failing test exists before its
  implementation task (tdd extension drives this via
  `specs/051-corpus-harness/tdd/test-list.md`).

### Parallel Opportunities

- Phase 2 tasks T002–T009 are file-disjoint [P].
- US3 (Phase 6) can proceed in parallel with Phases 3–5.
- Test files marked [P] within a phase run in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 + Phase 2 → stores green.
2. Phase 3 → the 3-feature fixture drives, stops, resumes.
3. STOP and validate (SC-001) before extending.

### Incremental Delivery

US1 → US2 (gates) → US4 (ledger totals) → US3 (audit) → US5 (status) →
Polish. Each story keeps the fixture suite green on its own.

---

## Notes

- The runner writes ONLY progress/ledger/audit-report files
  (data-model invariants) — never specs/, lib/, test/, manifest,
  waivers, or carve-out.
- Exit codes mirror `zfa tdd run`'s 0/1/2/3/4 scheme
  (contracts/corpus-harness.md).
- Commit after each task or logical group (`feat(051):` /
  `test(051):` / `fix(051):` prefixes).
