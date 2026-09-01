---
feature: tdd-make-drift-breaks-run-loop (bugfix #694, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: c21f5559
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # scope: changed contract, 1 deliberate mutant, caught, restored
mutants_survived: 0
suite: make_command 21/23 (2 failures PRE-EXISTING on base, unrelated), run_command 22/22, sc_006 3/3, step_runner 11/11
---

# TDD Verification: #694 `zfa tdd make` drift stop breaks the run loop

**Verdict: PASS_WITH_GAPS.** The skip transition is implemented, test-first
(RED recorded against the pre-fix code), and pinned at three levels —
command contract, step-contract parser, and the real driver loop — with one
deliberate mutant executed for real. Gap: 2 failures in
`make_command_test.dart` pre-exist on the base commit (verified by stashing
this fix and re-running) and are out of this fix's scope.

## Root cause (from issue, confirmed in source)

`lib/src/plugins/tdd/commands/make_command.dart` step 4 (at `ea399d96`): when
the pre-generation target-test re-run passed (`exitCode == 0`), make printed
a drift remediation, printed `outcome=drift`, set `exitCode = 1`. Downstream,
`StepRunner` (make success = exit 0 AND `outcome=green`) reported
`success=false, outcome='drift'`, and `run_command.dart`'s honest-stop path
stopped the whole feature: `zfa tdd run: step failed — behavior=X step=make
outcome=drift`. Any re-run of `zfa tdd run` over a feature with already-made
behaviors deadlocked at the first green target.

## Remediation (issue: skip/green transition)

- `make_command.dart`: already-green target → SKIP transition. Generation
  (plan/pipeline/post-run) never runs; flow falls through to the real suite
  baseline + guard; a green evidence entry with an explicitly empty
  `generation:` block is appended; summary prints `outcome=skipped`;
  exit 0. Suite NEW-failure regressions still stop with
  `outcome=regression` (unchanged path).
- `generation_plan.dart`: `MakeOutcome.drift` → `MakeOutcome.skipped`
  (documented exit-0 semantics).
- `step_runner.dart`: make success = exit 0 AND (`outcome=green` OR
  `outcome=skipped`).
- `specs/047-tdd-make/spec.md`: US2.AC3, edge case, FR-003, and Assumptions
  amended in place with dated `(amended 2026-09-01 by issue #694; was: …)`
  markers.

## Test-first evidence

| Behavior                                                            | Class  | Evidence                                                                                                                                             |
| ------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| U-694a: already-green make → exit 0, `outcome=skipped`, green evidence, no generation | PROVEN | `make_command_test.dart` U25/A6 rewritten FIRST; run against pre-fix code → failed (drift/exit 1 recorded); fix commit turns it green. sc_006 A6 rewritten in lockstep |
| U-694b: StepRunner parses `outcome=skipped` as make success (exit-0 only)            | PROVEN | `step_runner_test.dart` new U14 case added FIRST; failed against pre-fix parser (success=false); passes after the contract change                       |
| U-694c: driver loop advances past a skipped make and completes the feature           | PROVEN | `run_command_test.dart` new bug-694 test added FIRST (with fake `skip` token mirroring the real contract); failed pre-fix (drift stop); passes post-fix   |

RED commands (before fix, recorded output):

```
dart test test/plugins/tdd/services/step_runner_test.dart
Failing tests: U14 (issue #694): make succeeds on outcome=skipped …

dart test test/plugins/tdd/make_command_test.dart --preset=all \
  --plain-name "U25/A6 (issue #694)"
00:06 +0 -1: Some tests failed.
```

GREEN (after fix):

```
dart analyze lib/                                   → No issues found!
dart test test/plugins/tdd/services/step_runner_test.dart      → +11 All tests passed!
dart test test/plugins/tdd/run_command_test.dart --preset=all  → +22 All tests passed!
dart test test/plugins/tdd/scenarios/sc_006_...--preset=all    → +3 All tests passed!
dart test test/plugins/tdd/make_command_test.dart --preset=all → +21 -2 (see findings)
```

## Findings

| # | Severity | Finding                                                                                                                                                                                                                     | Evidence                                            |
| - | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1 | MED (pre-existing, out of scope) | `bug 657` test expects planner text `no generator for 'provision'` but the planner emits the STOP-ON-ROADBLOCK wording; failure reproduces with this fix stashed, on the base commit                                            | make_command_test.dart:494; verified via `git stash` |
| 2 | MED (pre-existing, out of scope) | `SC-004` expects `outcome=unexpressible` for B-200 but the planner now maps a 2-step plan → generation-error; reproduces with this fix stashed, on the base commit                                                              | make_command_test.dart:815; verified via `git stash` |
| 3 | LOW      | The skip path still runs the full suite twice (baseline + guard) — same cost as a generation make; a cheaper single-run variant was rejected to keep the regression guarantee identical                                                       | make_command.dart steps 5/9                         |

No `HIGH` smells in the new/changed tests: each asserts specific contract
values with reasons, no conditional logic, deterministic, isolated fixtures,
slow-tier tests use the existing `TddFixture`/fake-zfa helpers (no bypassed
test utilities).

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                                       | Behavior | Survived | Judgment                                                                                  |
| ---------------------------------------------------------------------------- | -------- | -------- | ----------------------------------------------------------------------------------------- |
| remove `skipped` from make's success contract in `step_runner.dart`           | U-694c   | No       | Caught by the bug-694 loop test (run stopped, test failed); mutant restored, suite re-run green |
| (restore accident during the cycle) fix itself reverted via checkout          | —        | —        | Detected immediately (empty diff vs expected), fix re-applied, both suites re-verified green     |

Sample: the changed success contract is one predicate — exhaustively sampled.

## Traceability (issue criteria → tests)

| Issue criterion                                                                  | Test                                   | Real entry point?                                       |
| -------------------------------------------------------------------------------- | -------------------------------------- | ------------------------------------------------------- |
| already-green make does not exit non-zero on drift                                | make_command U25/A6 (in-process CLI)    | yes — real `CliRunner` + real `dart test` subprocesses   |
| run-state flips to green / loop proceeds past completed behaviors                  | run_command bug-694 test (real driver)  | yes — real spawn path through the fake zfa binary        |
| no new suite failures introduced by the transition                                 | suite guard lines asserted in evidence  | yes — real baseline + guard runs in the fixture project  |
| full suite → NO NEW failures (shared verify)                                       | deferred to the branch-level verify run | — (shared verify section of the bug combo)               |

## What was not audited

- The 2 pre-existing make_command failures were confirmed pre-existing and
  triaged as out of scope; they are NOT fixed by this branch (Hard Rule 1:
  never fix what you find — they belong to the planner-message owner).
- `zfa tdd run` was not executed against a real generated Flutter project
  (issue's macOS repro); the driver-level test with the real spawn path
  stands in.
- No mutation tool run (profile has none); one deliberate mutant used.
