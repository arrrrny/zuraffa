---
bug: 693
slug: tdd-run-drift-misclassified-as-generation-error
verdict: PASS
verified_at: fix/693-tdd-run-drift-misclassified-as-generation-error (pre-PR)
suite: tdd plugin fast suite 339 passed / driver slow tiers 23 + 16 passed / dart analyze clean
---

# TDD Verification: #693 tdd run classifies drift as green success

## Root cause

After fix #657, `zfa tdd make` legitimately returns `drift` (the outcome's
own contract: *target test already passes — non-zero exit, no green entry
appended*) for behaviors whose stub/implementation is already enough.
`zfa tdd run`'s outcome handling in `_driveBehavior`
(lib/src/plugins/tdd/commands/run_command.dart) had no `drift` case: any
`make` whose outcome is not `green` fell into the honest-stop branch, so the
run reported `step failed — behavior=U1 step=make outcome=drift` (surfaced to
users of the #657-era binary as the generation-error family), left the
behavior RED/pending, and hard-stopped the feature — exactly the reported
"U1 stays pending" symptom.

## Remediation

Add `drift → green` to the run driver's outcome mapping: when a `make` step
reports `drift`, the driver treats it as a success —

- records the green evidence `make`'s drift path deliberately never writes
  (one `kind: green` cycle-log entry naming the drift provenance, emitted
  only when no green evidence exists yet — no duplicates);
- advances the behavior to GREEN (the make target state via
  `_targetStateFor('make')`);
- prints `[run] <id> make -> green (drift)` and continues the step window,
  so refactor runs and marks the behavior DONE per the normal contracts
  (FR-003 evidence intact: refactor's red+green preflight now passes).

This keeps the honesty rules: nothing is marked DONE without evidence, the
drift-green entry is explicit about being driver-recorded, and resume-safe
(the persisted evidence survives reconcile; no in-memory-only state).

## RED evidence (pre-fix, real driver tests)

`test/plugins/tdd/run_command_test.dart` (fake scripted zfa, the harness
from spec 049):

```
00:00 +0 -1: bug #693: make reporting drift maps to green — ... [E]
  Expected: <0>
    Actual: <1>
  run: feature=090-run-driver result=stopped pending=2 red=1 green=0 done=0 stopped_at=B-001:make
00:00 +0 -2: Some tests failed.
```

The pre-fix driver stopped the whole feature at `B-001:make` with the
behavior RED — the bug, reproduced.

## GREEN evidence (post-fix, same tests)

```
00:00 +1: bug #693: make reporting drift maps to green — ...
00:00 +2: bug #693: an existing green evidence entry is not duplicated when make reports drift
All tests passed!
```

The first test asserts the full post-fix contract: no step-failure line, the
`[run] B-001 make -> drift` outcome line followed by
`[run] B-001 make -> green (drift)`, refactor spawned for B-001, B-002/B-003
still driven, B-001 DONE, the driver-recorded green evidence present in
`tdd/cycle-log.md`, and `result=complete pending=0 red=0 green=0 done=3`
with exit 0. The second asserts idempotence: an existing green entry is not
duplicated.

## Suite

| Suite | Result |
| ----- | ------ |
| `dart analyze` | No issues found |
| `dart test --preset=all test/plugins/tdd/run_command_test.dart` | 23/23 (incl. 2 new) |
| `--preset=all` sc_013/sc_014/sc_015/sc_016 (driver scenarios) | 16/16 passed |
| `dart test test/plugins/tdd` (fast tier, whole plugin) | 339/339 passed |
| `dart format` on changed files | clean (0 changed) |

Full-chunked-suite note (honest): `tools/run_tests_chunked.sh` completed
("OK: all chunks passed") on this branch's parent (fix/690), whose tree is
byte-identical to this branch except `run_command.dart`,
`run_command_test.dart`, and this verification report. On this branch the
affected areas were re-run green (the rows above); a second full chunked
pass was infeasible in this sandbox (per-chunk kernel rebuild exceeds the
command time ceiling and background processes do not persist here).

## Scope disclosure

- The bug assessments for #693 were not present in `.specify/bugs/` on any
  branch of this clone; the remediation follows the issue text + task brief
  (which agree): "add drift → green to the outcome mapping table …
  transition the behavior to green/done and proceed."
- The issue's quoted `outcome=generation-error` string corresponds to the
  #657-era reporting of the same fall-through (any non-green make outcome
  landing in the failure branch); the current tree's stop line names
  `outcome=drift` — same mapping-table gap, same remediation.
- The full verify audit (mutation testing) was not run — bug-fix
  verification, not a feature audit.
