# TDD Cycle Log — Spec 1652-refactor-digest-gate (append-only)

## Baseline (pre-loop)

- Feature: specs/1652-refactor-digest-gate (issue #1652, perf).
- Suite state before any behavior work: fast tier green on `master`
  (06cbf85e); the defect is an ECONOMICS defect (redundant re-proofs),
  not missing code — the reds are evidence-shape reds (A1: the pipeline
  runs where it should inherit; U5: the record is never written), and
  every fallback row is green-by-design pre-fix.
- Test list: 8 behaviors — 2 acceptance (A1 red, A2 guard), 6 unit
  (U1–U4 command-level guards, U5 red, U6 guard). All driven in the two
  existing harness tiers; no real AOT compile anywhere.
- Driving toolchain: Dart 3.13.3 stable on macOS arm64; TMPDIR pinned to
  the clone-local `.tmpdir/` for every run (issue #1642 hazard).

## Cycle C1 — the command-level suite (A1, A2 + guards U1–U4)

- **RED** (pre-fix, recorded before the fix):
  - `TMPDIR=.tmpdir dart test test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart`
    → first run `+0 -1` then `+7 -1: Some tests failed.` — A1 failed on
    the economics assertion itself: `Expected: <0> Actual: <1>` suite
    spawn (the pipeline ran where it must inherit), with no
    `make-post-state` evidence in the output. Every guard green: A2
    (drift → pipeline), U1a-c (context mismatch → pipeline), U2
    (corrupt → pipeline; the harness deletes the #1588 ledger per
    iteration so the corrupt-record fallback is what is exercised),
    U3 (flag-less / --full-reproof → pipeline), U4 (ledger precedence).
  - Classification: assertion red for the right reason — the record is
    written by the test and ignored by today's refactor.
- Test-shape fix during red (assertions unchanged): U2's second
  iteration initially failed because the FIRST iteration's green
  application legally wrote the #1588 ledger, which then inherited —
  the test now deletes `pass-batch.json` per iteration.

## Cycle C2 — the driver-level suite (U5, U6)

- **RED**: `dart test test/plugins/tdd/run_driver_1652_make_post_state_test.dart`
  → `00:00 +0 -4: Some tests failed.` — U5a/U5b/U5c all fail on the
  missing record (no writer exists); U6 shares the root cause (its
  staleness check needs the record). Noted in the test list.

## Cycle C3 — the fix (T101–T104): green + regression scope

- **GREEN** step: `make_post_state.dart` (the record type, shared key
  helpers), `run_driver_core.dart` (the `_recordMakePostState` helper +
  the make-green hook, gated on the new `recordMakePostState` flag at
  the phase-1 and phase-2a call sites; outcome must be exactly `green`
  — the #741 skip writes nothing), `refactor_command.dart` (the
  make-post-state rung inside `passBatch && !fullReproof`, after the
  ledger miss, ledger precedence kept), `pass_batch_ledger.dart`
  (doc-only: the record named as the forward-progress rung).
- `dart test test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart`
  → `01:38 +8: All tests passed!`
- `dart test test/plugins/tdd/run_driver_1652_make_post_state_test.dart`
  → `00:42 +4: All tests passed!`
- Regression: `bug_1588_..._test.dart` (`--preset=all`) → `+16: All
  tests passed!`; new suites after format → `+12: All tests passed!`.
- `dart analyze` on all changed files → `No issues found!`; `dart
  format` applied (3 files re-flowed) and suites re-run green.
- Refactor pass: none needed beyond format re-flow.

## Pre-existing failure noted (not this feature)

- `refactor_command_test.dart` A12 ("a project without bin/zfa.dart
  refactors green via --zfa-bin") fails on CLEAN `master` @ 06cbf85e
  (verified in a throwaway master worktree: same `Expected: contains
  'build' / Actual: []`), so the fake zfa build spawn it expects is
  already absent on master before this branch. Out of scope; flagging
  for the maintainer.

## Cycle C4 — verify remediation (M1 + M7 survived pass 1, now killed)

- **Audit pass 1**: mutation sampling — M2/M3/M4/M5 killed (U1c, U3's
  two arms, U5b); M1 (test-digest comparison dropped) SURVIVED `+12`
  and M7 (suite-template comparison dropped) SURVIVED `+8`: no test
  drifted `test/` alone or varied the template between record and
  spawn. Verdict FAIL; remediation tasks R1/R2 appended to tasks.md.
- **Remediation**: U7 (test/ drift after the make → pipeline) and U8
  (record's suite template differing from the resolved template →
  pipeline) added to the command-level suite.
- **Mutant re-run**: M1 → `+9 -1` (U7 red) — KILLED; M7 → `+9 -1` (U8
  red) — KILLED. Restoration `cmp`-verified; suite re-run green `+10`.
- Final audit verdict: PASS (6/6 mutants killed, one remediation pass).
