# TDD Verification — bug #828 (cycle-log evidence integrity)

- **Branch**: `fix/828-tdd-cycle-log-evidence-integrity`
- **Date**: 2026-09-02
- **Mode**: bug-fix TDD loop (red -> green -> verify), spec-kit TDD extension v1.1.2
- **Audit context**: same-session audit (not independent cold-context); mutation
  testing not run (`quick`-equivalent scope) — recorded as unmeasured below.

## Verdict: PASS_WITH_GAPS

The fix is green, the driver suite is green, and the full chunked fast suite
passes with no new failures. Gaps: mutation testing unmeasured, and the audit
was written by the same session that wrote the fix (per the rubric these are
recorded, not assumed away).

## 1. Root cause (from the committed assessment, confirmed in code)

Three stores (`tdd/run-state.json`, `tdd/artifacts.json`, `tdd/cycle-log.md`)
are written at different times by different processes without transactional
guarantees. Two concrete holes confirmed by reading
`lib/src/plugins/tdd/commands/run_command.dart`:

1. `_reconcile` demoted `done` claims without evidence and bootstrapped
   `pending` claims, but never checked `green` claims against the cycle-log.
   An interrupted run that left `run-state.json` claiming green with gen
   artifacts present resumed straight at `refactor`; the driver's evidence
   misfire gate (correctly) refuses for missing red+green proof and the run
   stops `runner-error` at `<id>:refactor` on EVERY resume — the unrecoverable
   hard-stop the issue reports.
2. The driver's per-step commit spans two processes (the spawned step child
   appends evidence; the driver advances run-state). A crash inside that window
   left the stores divergent with no convergence path.

## 2. Red evidence (captured, pre-fix)

Driven through `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
against the fixture's scripted fake zfa (same harness as
`run_command_test.dart`):

- `bug 828 RED: a green claim with gen artifacts but NO cycle-log evidence ...`
  -> `Expected: <0> Actual: <2>` with
  `zfa tdd run: step failed — behavior=B-001 step=refactor outcome=runner-error`
  (the hard-stop reproduced).
- `... a green claim with red evidence but no green evidence re-enters at make`
  -> same exit-2 hard-stop at the refactor misfire.
- journal replay -> `Expected: ['refactor B-001'] Actual: ['make B-001',
  'refactor B-001']` (no write-ahead journal existed).
- doctor drift / healthy / journal -> the `tdd doctor` subcommand did not exist
  (`Could not find an option named "--feature"`; exit 0 on drift fixtures).
- hash chain -> no `- schema:` / `- hash:` lines in appended entries; tamper
  undetectable.

Control tests that pass pre- and post-fix (resume semantics preserved):
`a green claim WITH complete red+green evidence keeps its resume semantics`,
`a pending journal whose evidence never landed is discarded`, `every committed
step clears the journal`.

## 3. Green evidence (captured, post-fix)

Implementation (all under `lib/src/plugins/tdd/`):

- **Resume reconciliation** (`commands/run_command.dart` `_reconcile`): a green
  claim now stands only on its green evidence (matching-evidence rule); an
  evidence-less green claim demotes to the highest state the evidence backs
  (red when a red entry exists, else pending) and re-drives from the earliest
  incomplete step. `done` (U21) and `pending` (bug #682 bootstrap) semantics
  are unchanged. Red claims keep their resume semantics — the red half cannot
  be fabricated, and the refactor misfire gate names it honestly (the #682
  contract).
- **Single transactional writer** (`services/tdd_transaction.dart` + driver):
  every spawn is wrapped `begin` (write-ahead `tdd/journal.json`, fsync) ->
  spawn -> commit (state save fsync'd) -> `clear`. On resume the journal is
  replayed: evidence landed -> the state advance is applied without
  re-spawning the step; evidence absent -> the journal is discarded and the
  in-flight marker re-drives the step. `RunStateStore.save`,
  `CycleLog.append`, and `ArtifactRegistry._writeRecords` fsync before their
  rename/return.
- **Versioned evidence schema + hash chain** (`services/cycle_log.dart`):
  entries carry `- schema: 1`, `- prev-hash:`, `- hash:` (sha256 over the
  certified facts + previous link, per behavior red -> green -> refactor).
  Legacy entries stay valid (schema-0, byte-compatible rendering, U10).
- **`zfa tdd doctor`** (`commands/doctor_command.dart`, registered in
  `tdd_command.dart`): read-only drift report across the three stores —
  claim-vs-evidence, registry-vs-disk, pending journal, hash-chain breaks —
  each with a `--> fix:` line; summary `doctor: feature=<f> drifts=<n>`;
  exit 1 on drift.

Test results (all run in this session):

| Suite | Result |
| --- | --- |
| `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` | 11/11 pass |
| `dart test test/plugins/tdd` (fast tier) | 405/405 pass |
| `run_command_test.dart` + run scenarios (`--preset=all`) | pass (see §5) |
| `dart analyze` (changed files) | 0 issues (47 pre-existing `examples/todo_tdd` issues untouched) |
| `tools/run_tests_chunked.sh` (67/67 chunks) | OK: all chunks passed |
| `dart format .` + `git diff --stat` | no formatting diffs outside the fix files |

## 4. Test strength

- Behavioral asserts, not implementation asserts: the new tests assert exit
  codes, step-invocation sequences (which steps re-drove), persisted
  run-state, doctor output (`drift`, `--> fix:`, exit codes), and cycle-log
  chain lines — they would fail if the fix regressed to the hard-stop.
- Tamper detection is exercised by rewriting a certified exit code and
  asserting the doctor names the hash break with a fix line.
- Mutation testing: **unmeasured** (not run in this scope). The misfire-gate
  and reconciliation branches are exercised from both sides (evidence present
  vs absent), which is the mutant-kill surface for this fix, but the score is
  not measured — recorded as a gap.

## 5. Suite notes (honest deltas)

- `run_command_test.dart` bug-734 phase-2b test UPDATED: bug #828 supersedes
  the skip-and-stop band-aid for evidence-less green claims — the resume now
  re-drives make (the earliest incomplete step) and the re-certified behavior
  refactors normally. The per-behavior gate remains in the driver as a
  defensive net. The updated test documents the supersession inline.
- `run_command_test.dart` bug-691 test FAILS ON PRISTINE MASTER TOO (verified
  by stashing this branch and re-running: same failure). Pre-existing, out of
  scope for #828, not introduced by this branch.
- Analysis issues (47) are all in `examples/todo_tdd/` (pre-existing example
  subpackage with missing generated files); zero issues in changed files.

## 6. Remediation tasks

- [ ] Run mutation testing on `run_command.dart` `_reconcile` / `_replayJournal`
  and `tdd_transaction.dart` (follow-up, epic #848 Wave 1).
- [ ] Pre-existing bug-691 failure on master: bootstrap promotion of
  red+green-evidenced pending claims to DONE skips the unexpected-green path
  the test exercises — triage separately.
- [ ] Consider `zfa tdd doctor --json` when the recovery-commands epic lands
  its JSON verdict contract.
