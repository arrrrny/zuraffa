**Template Version**: `zuraffa-1.0`

# Plan: 1652-defer-phase1-refactor-to-batch

## Technical Context

- Language/Dart SDK: ^3.11.0 (repo), running on Dart 3.13.4 stable.
- CLI surfaces involved:
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` — the single
    home of the run step loop (`run_command.dart` and
    `run_engine_command.dart` delegate to `RunDriverCore`; the skin
    lane has its own conformance drive and no refactor step). The
    phase-1 lane loop (~L993–1103) drives `_stepsFor`'s ladder
    `['gen', 'verify-red', 'make', 'refactor']` per behavior with
    `deferralAllowed: true`, `batchRefactor: true` (#1624) and
    `recordMakePostState: true` (PR #1662). The deferral gate sits at
    the top of the step loop (~L1993–2008): a `refactor` step defers
    pre-spawn when the suite has reds (`_hasRedBehavior`) or
    pending-with-artifacts behaviors (`_hasPendingWithArtifacts`) —
    bugs #635/#734.
  - Phase-2b batch pass (~L1189–1269, bugs #635/#734; issue #922): the
    same `_driveBehavior` with `steps: ['refactor']`,
    `deferralAllowed: false`, `batchRefactor: true` per green behavior
    whose own test is certified green. `_refactorBatchArgs` appends
    `--pass-batch` and the lane's parked BLOCKED ids as
    `--exempt-behaviors` (#1588). NOT modified (hard constraint).
  - `lib/src/plugins/tdd/services/pass_batch_ledger.dart` — the
    feature's `tdd/pass-batch.json` gate record; `matches()` keys on
    suite/baseline/config/exempt + byte-identical `lib/`+`test/`
    digests. NOT modified (hard constraint). In phase 2b all makes are
    complete, the tree is byte-stable between consecutive spawns, and
    the ledger inherits — the property the deferral leans on when the
    make-post-state record misses.
  - `lib/src/plugins/tdd/services/make_post_state.dart` +
    `_recordMakePostState` (~L3116) — the PR #1662 digest gate. NOT
    modified (hard constraint). Composes: the first phase-2b spawn may
    inherit through it; the ledger covers the shapes it cannot.
  - Make success arms inside the step loop (both must feed the new
    predicate): the #694/#1331/#1345/#1398 skip/adopt/
    adopted-placeholder/adopted-interrupted arm (~L2179–2279,
    `continue` into the refactor step) and the generic success path
    (~L3086, `_maxState(state, _targetStateFor(step))`). The make
    arms' grading/state logic is NOT modified (hard constraint) — only
    a local boolean observation is added.
- Test seams (existing, reused):
  `test/plugins/tdd/helpers/tdd_fixture.dart` — scripted fake zfa
  (`writeFakeZfa` + `setStepOutcome`), argv log, step log
  (`stepInvocations`), run-state/test-list seeding,
  `CliRunner.runCapturing`. The argv log makes phase-1 refactor
  spawning OBSERVABLE; `runCapturing` output makes the deferral lines
  observable. Driver-level test shape per
  `bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`
  (fast tier: `writeProfile: false`, so no real suite spawns).

## Design

### 1. The predicate (one boolean, no new state)

`_driveBehavior` gains a local `madeGreenThisDrive` flag, initialized
false before the step loop:

- Set TRUE in the skip/adopt/adopted-placeholder/adopted-interrupted
  arm right where the behavior transitions green (`state = next;`) —
  the #694 skip transition itself is untouched; the flag only
  OBSERVES it.
- Set TRUE in the generic success path when `step == 'make'` — the
  normal green landing.
- Every other arm either stops the drive (make failures: the honest
  stop family) or leaves the flag false (gen, verify-red), which is
  exactly the resume re-entry shape FR-003 protects.

### 2. The gate (one condition extension)

The deferral gate becomes:

```dart
if (deferralAllowed &&
    step == 'refactor' &&
    (madeGreenThisDrive ||
        _hasRedBehavior(rows, updated) ||
        await _hasPendingWithArtifacts(...))) {
```

Properties:

- `deferralAllowed` is true only for the phase-1 call site — phase-2a
  (make) and phase-2b (refactor) pass false, so the batch pass can
  never defer into itself.
- Short-circuit order puts the cheap local boolean first: a forward
  cycle skips the registry scan `_hasPendingWithArtifacts` entirely
  (a small extra win; the scan stays for the resume window).
- The old predicate is a strict subset of the new one (FR-004): the
  change can only convert a phase-1 SPAWN into a deferral, never the
  reverse.
- The deferred arm's body is untouched: same state advance
  (`updated.advance(row.id, state)` — a no-op for green), same save,
  same `[run] <id> refactor -> deferred (phase 2)` line, same
  `_emitStep` (FR-002).

### 3. Downstream effects (no code, by construction)

- Phase 2b already iterates every `green` behavior and refactors it
  with the ledger opted in; the deferral only changes WHO arrives
  green at phase 2b (behaviors made this run now arrive with their
  refactor pending instead of already run in phase 1).
- Gate economics at the batch boundary: the first phase-2b spawn
  either inherits make's post-state record (PR #1662, when it matches
  the byte-stable tree) or pays the full pipeline once and records
  the #1588 ledger; every subsequent spawn on the unchanged tree
  inherits through one of the two gates — at most one full pipeline
  per lane per run, robust to record corruption/write failure/drift
  (SC-5).
- Hand-steps (#1568) and blocked contracts (#1007/#1544) never reach
  the gate with the flag true: make never succeeded for them (their
  arms return before the loop continues), so AC-4 holds without new
  code.
- The `refactor` not-green arm keeps both its branches; for the
  phase-1 site it becomes reachable only via the resume window (same
  as the pre-#1652 code for that window).
- Standalone `zfa tdd refactor` never enters `_driveBehavior` — the
  spec 048 FR-001 absolute-green contract is untouched by
  construction.

## Alternatives reconsidered

- **Digest-gate the phase-1 refactor against make's post-state**
  (issue proposal 2): ALREADY ON MASTER (PR #1662) and kept. It is
  best-effort derived data: every mismatch dimension (drift, corrupt
  record, failed write, baseline/config/suite-template/exempt-set
  change) costs the affected spawn a FULL pipeline — per behavior in
  the forward shape. This feature's deferral makes the economics
  structural (one pipeline per lane per run through the ledger across
  the byte-stable batch tree) and removes the eager spawn from the
  forward path; the two compose without interaction.
- **Scope the phase-1 preflight to the behavior's own test**
  (issue proposal 3): weakens the gate the phase-1 refactor provides
  for resume-window refactors and forks the preflight contract per
  spawn shape; the full-suite gate would then exist only in phase 2b
  anyway, so the scoped preflight is pure overhead.
- **Unconditionally defer every phase-1 refactor** (including the
  resume re-entry window): would strand MOCKED-state behaviors — the
  phase-2b loop iterates `state == green` only, so a deferred mocked
  refactor would never re-drive and the run could not complete.
  FR-003's windowed deferral avoids this without touching phase 2b
  (hard constraint).

## Verification

- New driver-level suite
  `test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart`
  (fast tier): forward-run deferral (SC-1/SC-2), skip-transition
  deferral (#694 shape), resume-window preservation (SC-3), honest
  stop with deferred refactors (AC-5), blocked-contract composition
  (AC-4).
- Red evidence recorded in `tdd/cycle-log.md` per behavior BEFORE the
  fix (the new tests fail against the pre-change driver); green
  evidence after.
- Existing suites per SC-4 re-run (unmodified except the two_cycle
  pinned step sequences, whose update is the fix's observable
  scheduling change); `dart analyze` + `dart format` per SC-6.
