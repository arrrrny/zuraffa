# Cycle Log: 991-tdd-run-phase0-no-analyze

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/run_command_test.dart --preset=all`
  → 40 passed, 1 failed (`bug #691` — verify-red unexpected-green
  transition; **pre-existing on clean master**, reproduced with the fix
  stashed)
- commit: `77e69f2`
- recorded: cycle 0, before any change
- `dart analyze`: 345 pre-existing issues, identical to master; none in the
  touched files

## Cycle 1 — U-991 RED (the bug, pinned as a test)

- suite: `dart test test/plugins/tdd/run_command_test.dart --preset=all
  --plain-name "U-991"` against the pre-fix tree (bare `build` spawn)
- result: **RED** — `Expected: <0> Actual: <2>`
- driver output (verbatim):
  ```
  [run] phase-0 entity User -> created
  [run] phase-0 build -> failed
     zfa build : analyze warnings reported
  zfa tdd run: phase-0 build failed (exit 1) — the run stops before any behavior is driven (bug #829).
  run: feature=090-run-driver result=runner-error pending=3 red=0 green=0 done=0 stopped_at=phase-0:build
  ```
- this is bug #991's exact failure shape: the analyze-gated build exits 1,
  the run stops with `runner-error` before any behavior is driven.

## Cycle 2 — GREEN (fix applied: spawn `['build', '--no-analyze']`)

- suite: `dart test test/plugins/tdd/run_command_test.dart --preset=all
  --plain-name "bug 829"`
- result: **5/5 passed** — U-829c, U-829d, U-829e, U-829f, U-991
- U-991 green evidence: exit 0, `[run] phase-0 build -> ok`, the argv log
  carries the `build --no-analyze` spawn, and behaviors were driven
  (`stepInvocations()` non-empty)
- full-file re-run: 41 passed, 1 failed — the same pre-existing `bug #691`
  failure (unrelated; see Baseline)

## Cycle 3 — U-991b RED (the counterpart guarantee, pinned pre-implementation of the test)

- suite: `dart test ... --plain-name "U-991b"` against the pre-fix tree
  (lib fix stashed, test present)
- result: **RED** — `Expected: <2> Actual: <0>`; driver output
  `[run] phase-0 build -> ok` — the bare spawn never reaches the scripted
  genuine failure, so the (future) stop contract is unproven pre-fix
- GREEN post-fix: exit 2, `phase-0 build -> failed`,
  `result=runner-error`, `stopped_at=phase-0:build`, no behavior driven

## Cycle 4 — deliberate mutants (both killed)

- M1 — the fix reverted: spawn back to bare `['build']`
  → U-991 **FAILS**: `Expected: <0> Actual: <2>`,
  `result=runner-error ... stopped_at=phase-0:build` (the bug reproduces)
- M2 — the stop neutered: `if (false && build.exitCode != 0)` on the
  phase-0 build verdict
  → U-991b **FAILS**: `Expected: <2> Actual: <0>` — a genuine build
  failure would be papered over and the run would continue
- both mutants reverted; clean fixed tree re-verified: U-991 + U-991b
  **2/2 passed**

## Refactor

- none required (runbook step 4: optional; the fix is a one-argv-constant
  change plus documentation).
