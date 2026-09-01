---
bug: 691
slug: tdd-run-unexpected-green-breaks-loop
verdict: PASS
verified_at: fix/691-tdd-run-unexpected-green-breaks-loop (pre-PR)
suite: tdd plugin fast suite 339 passed / driver slow tiers 22 + 16 passed / dart analyze clean
---

# TDD Verification: #691 tdd run skips already-green behaviors instead of failing

## Root cause

`zfa tdd run` drives every non-DONE behavior through the uniform cycle. When
a behavior was already completed by prior work (e.g. a manual
`zfa tdd gen`/`verify-red`/`make` sequence — the issue's A7), its target
test already passes, so the spawned `verify-red` classifies it
`unexpected-green` (certified=false, exit 1 — red_classifier.dart's honest
name for "expected red, found green"). The driver had no case for that
outcome: any failed step fell into the honest-stop branch, so the whole
feature stopped at `behavior=A7 step=verify-red outcome=unexpected-green`
with later behaviors never started. A run loop that cannot pass over
already-finished work is broken for exactly the resume/incremental case it
was built for.

## Remediation

Map `verify-red` + `unexpected-green` to a **skip, not a failure**: the
behavior is complete from prior work, so the driver clears the in-flight
marker, prints `[run] <id> verify-red -> skipped (already green)`, and lets
the step window continue with `make` — the remediation's "skip to make".
Make's own pre-generation drift check then re-verifies the green honestly
(reports `drift`; when the bug #693 mapping is also present, the run
transitions the behavior green from that outcome — the two fixes compose),
and refactor proceeds as usual. The behavior's prior red+green evidence (the
canonical scenario leaves it behind) keeps every evidence contract intact.

Honest-stop semantics are unchanged for every other failure class: a
`not-certified-red`, `regression`, or any other non-certified outcome still
stops the run (FR-007) — only `unexpected-green`, which is success-shaped
information about already-finished work, maps to a skip.

## RED evidence (pre-fix, real driver test)

`test/plugins/tdd/run_command_test.dart` (fake scripted zfa): verify-red
scripted to `unexpected-green` on a behavior whose prior work left red+green
evidence in the cycle log:

```
00:00 +0 -1: bug #691: verify-red reporting unexpected-green ... [E]
  Expected: <0>
    Actual: <1>
  run: feature=090-run-driver result=stopped pending=3 red=0 green=0 done=0 stopped_at=B-001:verify-red
```

The pre-fix driver stopped the feature at `B-001:verify-red` with all three
behaviors unresolved — the bug, reproduced.

## GREEN evidence (post-fix, same test)

```
00:00 +1: All tests passed!
```

The test asserts the post-fix contract: no step-failure line, the outcome
line `[run] B-001 verify-red -> unexpected-green` followed by
`[run] B-001 verify-red -> skipped (already green)`, the window continued to
`make B-001` (skip-to-make, per the remediation), B-002/B-003 still driven,
and `result=complete pending=0 red=0 green=0 done=3` with exit 0.

## Suite

| Suite | Result |
| ----- | ------ |
| `dart analyze` | No issues found |
| `dart test --preset=all test/plugins/tdd/run_command_test.dart` | 22/22 (incl. 1 new) |
| `--preset=all` sc_013/sc_014/sc_015/sc_016 (driver scenarios) | 16/16 passed |
| `dart test test/plugins/tdd` (fast tier, whole plugin) | 339/339 passed |
| `dart format` on changed files | clean |

Full-chunked-suite note (honest): `tools/run_tests_chunked.sh` completed
("OK: all chunks passed") on this branch's parent (master @ ea399d96) via
the fix/690 branch run, whose tree is byte-identical to this branch except
`run_command.dart`, `run_command_test.dart`, and this verification report.
On this branch the affected areas were re-run green (the rows above); a full
chunked re-pass was infeasible in this sandbox (per-chunk kernel rebuild
exceeds the command time ceiling; background processes do not persist here).

## Scope disclosure

- The bug assessments for #691 were not present in `.specify/bugs/` on any
  branch of this clone; the remediation follows the issue text + task brief
  (which agree): "detect already-green tests and skip them … map
  unexpected-green to a skip/done transition rather than a hard failure."
- Branch independence: this PR contains only the #691 fix. With #693 merged,
  the skip composes (make then reports `drift`, which the run maps to
  green); without it, make reports green/other outcomes per its own
  contract — the skip itself is independent.
- The full verify audit (mutation testing) was not run — bug-fix
  verification, not a feature audit.
