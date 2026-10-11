# Bug Fix: `tdd run` parks forever on the first BLOCKED contract

- **Slug**: 1544-parks-forever-on-first-blocked-contract
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Verification**: ./test.md
- **Status**: applied (verified — see ./test.md)
- **TDD artifacts**: `tdd/test-list.md`, `tdd/verification.md` (repo root)
- **Branch**: `fix/1544-parks-forever-on-first-blocked-contract`
- **Closes**: #1544

## Tooling note (spec-kit)

The repo already carries an initialized `.specify/` tree (templates, scripts,
and the `bug` + `tdd` extensions) — re-running `specify init` risked
clobbering exactly the files the workflow says to preserve, so the extension
commands' established artifact conventions (as exercised by
`.specify/bugs/cycle-log-phantom-sections/` and friends) were followed
directly. No template or script was modified.

## Summary

`blocked` is a legitimate PER-BEHAVIOR verdict (issue #1007), but the run
driver coupled it to a run-level lane termination: the first blocked contract
stopped the pass, and every resume re-attempted the same behavior's
verify-red with no progress signal — A2..A11 were unreachable.

The fix separates the two concerns in
`lib/src/plugins/tdd/commands/run_driver_core.dart`. The blocked VERDICT
itself (state advance to `BehaviorState.blocked`, no make/refactor for it,
the `contract-blocked.<id>.json` receipt written by verify-red) and the state
machine are untouched; only the driver's blocked handling and resume logic
changed.

## Changes

1. **Park + continue (the issue-#1007 arm in `_driveBehavior`)** — the arm
   still advances the behavior to BLOCKED and saves, but now prints a park
   note and returns `stop: null` instead of a run-terminal
   `result: 'blocked'` stop. The phase-1 loop continues with the remaining
   behaviors, each driving to its own verdict. The mid-run resume hint moved
   to the end-of-pass terminal block.

2. **Phase 2a guard** — `_phaseTwoMakeSteps` drives `make` for a blocked
   state, which the park newly reaches: the phase-2a loop now skips blocked
   behaviors (make NEVER spawns for a blocked contract, issue #1007 — the
   constraint now enforced in the phase the park newly reaches).

3. **End-of-pass blocked terminal** — after phase 2b, if any behavior is
   parked at BLOCKED the run prints any refactor/widget skip blocks beside
   the blocked block (`blocked for <ids> — the declared contract(s) are not
   satisfied (issue #1007)` + the resume hint naming the new skip-with-
   receipt resume behavior) and stops with `result=blocked blocked=N`,
   `stopped_at=<first blocked>:verify-red`, exit 1. Bounded, resumable
   progress (FR-007), never a fake DONE (FR-008).

4. **Resume skip with receipt** — in the phase-1 loop, an ALREADY-blocked
   contract behavior is skipped (receipt line
   `[run] <id> verify-red -> skipped (still blocked since <ts>)` + a
   `step-verdict.v1` event with outcome `skipped`) when NOTHING watched
   changed since its blocked verdict:
   - the verdict's receipt (`.zfa/receipts/contract-blocked.<id>.json`,
     written by the real `zfa tdd verify-red`) exists and parses;
   - the seam file (the behavior's generated contract test) is not newer;
   - the contract row's file (`tdd/test-list.md`) is not newer;
   - no file under `lib/` (the implementation) is newer than the verdict.
   Any change signal — or a missing/unparseable receipt, a gone seam file, or
   a probe error — fails OPEN and re-drives the behavior honestly (the
   unblock path: implement the contract, resume, verify-red re-classifies).

## Not changed (constraint compliance)

- The blocked verdict, its receipt schema, verify-red, make/refactor: the
  contract lane and state machine are untouched.
- `_stepsFor` for blocked (verify-red re-entry window) is untouched — the
  skip happens before it for unchanged worlds, and changed worlds re-drive
  exactly the pre-#1544 window.
- Non-blocked resume: the red/mocked/green/pending resume windows, the
  deferral logic and the honest stops are byte-identical (pinned by the
  guard test and the untouched run-command suites).
- The `result=blocked` summary token, counts (`blocked=N` via
  `laneCounts`), exit code (1) and the receipt verdict mapping are
  unchanged — the same token now arrives at `_finish` from the end-of-pass
  terminal instead of a mid-loop stop.

## Files

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — the four changes
  above (+ helpers `_unchangedBlockedSince`, `_isNewerThan`,
  `_treeChangedAfter`; + the `contract_blocked_receipt.dart` import).
- `test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` —
  the red→green bug suite (6 tests).
