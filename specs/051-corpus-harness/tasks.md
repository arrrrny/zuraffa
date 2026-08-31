# Tasks: `zfa tdd corpus` — batch loop driving, provenance audit, gap ledger

**Input**: Design documents from `/specs/051-corpus-harness/` (spec.md,
plan.md, research.md, data-model.md, contracts/corpus-harness.md,
quickstart.md)

**Prerequisites**: plan.md (required), spec.md (required), research.md,
data-model.md, contracts/

**Tests**: MANDATORY — the tdd extension drives this feature test-first.
Behavior markers (`[A1]`, `[U1]`, …) trace tasks to
`specs/051-corpus-harness/tdd/test-list.md`; `/speckit.tdd.run` ticks a
task's checkbox only when it can read a behavior id from it, and every
behavior's test is written and observed RED before the implementation
task that turns it green may run.

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

- [X] T001 Register `CorpusCommand` parent with `run`/`status`/`audit`
  subcommands in `lib/src/plugins/tdd/commands/corpus_command.dart` +
  wire into `lib/src/commands/tdd_command.dart` (each subcommand file
  created as a usage-printing skeleton); update
  `test/plugins/tdd/tdd_command_smoke_test.dart` to expect `corpus` and
  its three subcommands in `zfa tdd --help`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the models + stores + spawner every P1 story consumes.
Test-first: each group's failing tests land before its implementation.

- [X] T002 [P] [U1] [U2] Write the failing manifest-model tests FIRST in
  `test/plugins/tdd/models/corpus_models_test.dart`: decode preserves
  file order with optional sourceCorpus/importedAt; every malformed
  shape (invalid JSON, non-object root, non-list features, row missing
  name/ready, non-bool ready) is rejected naming the file + recovery —
  observe red before the model exists
- [X] T003 [P] [U1] [U2] Implement `CorpusFeature` + `CorpusManifest`
  (fromJson with corrupt → `CorpusManifestException` naming recovery) in
  `lib/src/plugins/tdd/models/corpus_manifest.dart` (depends on T002 red)
- [X] T004 [P] [U6] Write the failing progress-model tests FIRST in
  `test/plugins/tdd/models/corpus_models_test.dart`: progress round-trips
  per-feature state, gate, stoppedAt, waiver, in-flight marker, dropped —
  observe red
- [X] T005 [P] [U6] Implement `FeatureCorpusState`, `FeatureProgress`,
  `CorpusWaiver`, `CorpusProgress` (toJson/fromJson) in
  `lib/src/plugins/tdd/models/corpus_progress.dart` (depends on T004 red)
- [ ] T006 [P] [U11] Write the failing ledger-totals tests FIRST in
  `test/plugins/tdd/models/corpus_models_test.dart`: found/filed/merged/
  blocking compute from entries — observe red
- [ ] T007 [P] [U11] [U12] [U13] [U14] Implement `GapLedgerEntry`
  (gap + resolution kinds, status tokens, totals helper) in
  `lib/src/plugins/tdd/models/corpus_ledger.dart`, then the failing
  store tests FIRST in
  `test/plugins/tdd/services/gap_ledger_store_test.dart` (monotonic ids,
  complete FR-007 fields, byte-identical prefix after appends,
  resolution entries leave the resolved entry untouched), then
  `GapLedgerStore` (load/append/atomic rename) in
  `lib/src/plugins/tdd/services/gap_ledger_store.dart` (depends on T006
  red)
- [X] T008 [P] [U3] [U4] [U5] Write the failing manifest-store tests
  FIRST in
  `test/plugins/tdd/services/corpus_manifest_store_test.dart`: absent
  manifest → no-manifest outcome naming the path; carve-out
  `{carveouts: [{path, reason}]}` decode + malformed shape error;
  waivers decode + absent file → empty — observe red
- [X] T009 [P] [U3] [U4] [U5] Implement `CorpusManifestStore` (manifest
  + carve-out + waivers readers, `.zfa/` path constants) in
  `lib/src/plugins/tdd/services/corpus_manifest_store.dart` (depends on
  T008 red)
- [X] T010 [P] [U7] [U8] [U9] [U10] Write the failing progress-store
  tests FIRST in
  `test/plugins/tdd/services/corpus_progress_store_test.dart`: injected
  mid-write failure leaves the previous file byte-identical; corrupt JSON
  stops naming recovery; live foreign pid refused while own/dead/absent
  never refuse; features absent from the manifest land in `dropped` —
  observe red
- [X] T011 [P] [U7] [U8] [U9] [U10] Implement `CorpusProgressStore`
  (atomic temp+rename save, load corruption gate, pid in-flight refusal,
  dropped computation) in
  `lib/src/plugins/tdd/services/corpus_progress_store.dart` (depends on
  T010 red)
- [ ] T012 [P] [U15] [U16] [U17] [U18] Write the failing step-runner
  tests FIRST in
  `test/plugins/tdd/services/corpus_step_runner_test.dart` (injected
  spawner, no real processes): run argv + `run:` line parse with
  success = exit 0 AND result=complete; verify `mutation:` gate parse
  with success = exit 0 AND gate=pass, non-pass label surfaced; missing
  summary line → runner-error; spawn failure → runner-error never a
  crash — observe red
- [ ] T013 [P] [U15] [U16] [U17] [U18] Implement `CorpusStepRunner`
  (spawn `tdd run`/`tdd verify` via `--zfa-bin` or `dart bin/zfa.dart`,
  injectable spawner, machine-line parsing) in
  `lib/src/plugins/tdd/services/corpus_step_runner.dart` (depends on
  T012 red)

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

- [ ] T014 [US1] [A1] [A4] [U23] Write the failing corpus-run command
  tests FIRST in `test/plugins/tdd/commands/corpus_run_command_test.dart`
  (slow tier: CliRunner in-process + fake zfa sub-process): a 2-feature
  manifest drives run-then-verify per feature in manifest order, the
  done feature records its gate, the `corpus:` summary line is the final
  line with exit 0; a feature whose fake run exits non-zero (each
  outcome token) stops the corpus non-zero with a ledger entry naming
  that outcome and no later feature spawned — observe red
- [ ] T015 [US1] [A1] [A4] [U19] [U20] [U21] [U22] [U23] [U24] Implement
  the driving loop in
  `lib/src/plugins/tdd/commands/corpus_run_command.dart`: manifest read →
  progress load → concurrent refusal → per-feature mark-driving → spawn
  run → spawn verify → gate → persist, not-ready skipped and reported
  (never spawned), manifest-edit semantics (added → pending next run,
  removed → dropped reported `dropped=`), no-manifest → exit 2 naming
  the path, concurrent → exit 4, and the exit 0/1/2/3/4 contract per
  contracts/corpus-harness.md (depends on T014 red)
- [ ] T016 [US1] [A2] [A3] Write the failing resume + stop tests FIRST
  (same file): after a stop at feature k, re-run with the gap fixed
  performs 0 duplicate invocations of features 1..k-1 (fake argv log)
  and resumes at k; the stop earlier appended a complete ledger entry —
  observe red
- [ ] T017 [US1] [A2] [A3] Implement resume semantics in
  `lib/src/plugins/tdd/commands/corpus_run_command.dart`: skip
  done/waived features, spawn nothing for them, resume from the first
  non-done/waived feature, and STOP-ON-ROADBLOCK appends the ledger
  entry before exiting (depends on T016 red, extends T015)
- [ ] T018 [US1] [A1] [A2] [A3] Slow-tier e2e scenario (real
  sub-process fake zfa: drive → stop → ledger → fix → resume with 0
  duplicate invocations; concurrent-run refusal) in
  `test/plugins/tdd/scenarios/sc_020_corpus_harness_e2e_test.dart`
  (after T015/T017 green — the scenario pins the US1 independent test
  end-to-end)

**Checkpoint**: the US1 fixture scenario passes end-to-end (SC-001).

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

- [ ] T019 [US2] [A5] [A6] Write the failing gate-matrix + waiver tests
  FIRST in `test/plugins/tdd/commands/corpus_run_command_test.dart`:
  each gate label (`fail_survived`, `fail_timeout`, `preflight_red`,
  `not_assessed`) stops with a ledger entry carrying the label;
  a waiver matching the exact gate → feature waived with reason+actor+at
  in progress and the report; a waiver naming a different gate does not
  absorb the failure — observe red
- [ ] T020 [US2] [A4] [A5] [A6] Implement gate evaluation + waiver
  honoring in `lib/src/plugins/tdd/commands/corpus_run_command.dart`
  (waiver read from `.zfa/corpus/waivers.json`, exact gate match only,
  waiver copied into progress, surfaced in the final report) (depends on
  T019 red, extends T015)

**Checkpoint**: all five gate values honored; 0 silent absorptions
(SC-002).

---

## Phase 5: User Story 4 — The gap ledger (P1)

**Goal**: every stop lands in the append-only ledger with all six
fields; resolutions are new entries; the final report carries ledger
totals and names unresolved blocking gaps.

**Independent Test**: fixture stop → complete entry; resume+pass → old
entry untouched, resolution entry appended; report totals
found/filed/merged/blocking correct; blocking gaps named (SC-004).

- [ ] T021 [US4] [A10] [A11] [A12] Write the failing ledger-completeness
  + totals tests FIRST in
  `test/plugins/tdd/commands/corpus_run_command_test.dart`: every stop appends the five fields +
  issue-link placeholder with zero test/source edits (fixture tree
  checksummed); a resumed pass leaves the old entry byte-identical and
  appends a resolution entry; the final report lists totals and names
  unresolved blocking gaps — observe red
- [ ] T022 [US4] [A10] [A11] [A12] Implement resolution entries + ledger
  totals + blocking-gap listing in the run's final report
  (`lib/src/plugins/tdd/commands/corpus_run_command.dart` +
  `lib/src/plugins/tdd/models/corpus_ledger.dart` totals helpers)
  (depends on T021 red, extends T015/T017)

**Checkpoint**: ledger history survives resumes with 0 edits (SC-004).

---

## Phase 6: User Story 3 — Provenance audit (P1)

**Goal**: `zfa tdd corpus audit` attributes every `lib/` file to a
recorded zfa invocation or carve-out entry; unattributed files fail by
name; machine report + human summary.

**Independent Test**: fixture app with attributed + carve-out +
provenance files audits 100%; planting one unattributed file fails the
audit by name in 100% of runs; removing a carve-out entry flips its file
to unattributed (SC-003, US3.AC3).

- [ ] T023 [US3] [U25] [U26] [U27] [U28] [U29] [U30] Write the failing
  scanner tests FIRST in
  `test/plugins/tdd/services/provenance_scanner_test.dart`: registry
  subject_path attribution (absolute + relative), refactor `changed:`
  attribution, `.zfa/provenance/*.json` records (single + array),
  carve-out attribution, deterministic priority, POSIX path
  normalization — observe red
- [ ] T024 [US3] [U25] [U26] [U27] [U28] [U29] [U30] Implement
  `ProvenanceScanner` in
  `lib/src/plugins/tdd/services/provenance_scanner.dart` (lib/ walk +
  the four sources + normalization) (depends on T023 red)
- [ ] T025 [US3] [A7] [A8] [A9] [U31] [U32] Write the failing audit
  command tests FIRST in
  `test/plugins/tdd/commands/corpus_audit_command_test.dart`: 100%
  attribution exits 0 with the report JSON + `audit:` summary line; one
  planted unattributed file fails naming it; carve-out removal flips its
  file; no lib/ → trivial `files=0` pass — observe red
- [ ] T026 [US3] [A7] [A8] [A9] [U31] [U32] Implement `zfa tdd corpus
  audit` in `lib/src/plugins/tdd/commands/corpus_audit_command.dart`
  (report at
  `.zfa/corpus/audit-report.json`, summary line, exit 0/1/2) (depends on
  T025 red)

**Checkpoint**: audit is the epic's checkable proof artifact (SC-003).

---

## Phase 7: User Story 5 — Corpus status at a glance (P2)

**Goal**: read-only status with per-state counts, resume point, ledger
totals, and the stable `corpus:` summary line; exit 0 exactly when all
manifest features are done+gated/waived.

**Independent Test**: status on a partially driven corpus reports
counts + `resume_at` changing nothing; CI contract test pins the line
shape and exit codes (SC-005).

- [ ] T027 [US5] [A13] [A14] [U33] [U34] Write the failing status tests
  FIRST in `test/plugins/tdd/commands/corpus_status_command_test.dart`:
  per-state counts + `resume_at` + ledger totals reported read-only
  (files byte-identical before/after); exit 0 exactly when all manifest
  features done|waived; incomplete → 1; no-manifest → 2; corrupt → 3 —
  observe red
- [ ] T028 [US5] [A13] [A14] [U33] [U34] Implement `zfa tdd corpus
  status` in `lib/src/plugins/tdd/commands/corpus_status_command.dart`
  (read-only aggregation, per-state counts, resume point, ledger totals,
  `result=complete|incomplete` semantics) (depends on T027 red)

**Checkpoint**: CI can consume corpus state without prose scraping
(SC-005).

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T029 [A1] [A2] [A3] [A14] Full acceptance sweep: every outer-loop
  behavior's test green (A1–A14) — run
  `dart test test/plugins/tdd/ test/plugins/tdd/scenarios/` slow tier
  via `dart test --preset=all test/plugins/tdd/` scoped, or per-file
- [ ] T030 Run quickstart.md scenarios 1–4 against a scratch fixture
  app; record outcomes in the cycle log notes
- [ ] T031 `dart format` (zero diff) + `dart analyze` (0 issues) + full
  chunked test run (`tools/run_tests_chunked.sh`); fix any drift
- [ ] T032 Verify tdd artifacts complete (all behaviors DONE/PROVEN,
  cycle-log evidence, verification.md written by /speckit.tdd.verify) and
  commit history clean

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Phase 1 (command skeleton);
  BLOCKS all user stories. Within Phase 2 each test task precedes its
  implementation task (T002→T003, T004→T005, T006→T007, T008→T009,
  T010→T011, T012→T013).
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
- Test-first: every behavior's failing test exists (observed red) before
  the implementation task that turns it green (markers bind tasks to
  behaviors).

### Parallel Opportunities

- Phase 2 groups (models/stores/spawner) are file-disjoint [P].
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
