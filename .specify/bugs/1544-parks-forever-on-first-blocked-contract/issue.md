# Issue Record: tdd run parks forever on the first blocked contract

- **GitHub issue**: https://github.com/arrrrny/zuraffa/issues/1544
- **State**: OPEN
- **Title**: BUG 1544 — TDD RUN PARKS FOREVER ON FIRST BLOCKED CONTRACT — NO RUN-LEVEL CONTINUE-AFTER-BLOCKED
- **Filed by**: arrrrny
- **Related**: #1007 (contract lane blocked verdict origin), #1107 (blocked verdict degraded to result=stopped in the spec-1008 split)

## Note on the report phase

The bug is already tracked as issue #1544; this file records the existing
issue instead of filing a fresh one (no duplicate issue created).

## Issue body (summarized — see the linked issue for the verbatim text)

`tdd run` stops the whole run at the first BLOCKED contract behavior
(`result=blocked stopped_at=contract:A1:verify-red`), and every resume
re-attempts the SAME behavior — A2..A11 are unreachable. Each resume costs a
full refactor pass for zero progress.

Expected:

1. Resume must not re-attempt a still-blocked behavior unless something
   changed (seam file, contract row, implementation); skip unchanged blocked
   with receipt (`skipped: still blocked since <ts>`).
2. Continue past blocked in the same run — blocked behaviors are parked, not
   fatal; drive the remaining contracts to their own verdicts, then stop with
   `result=blocked blocked=N`.

Hard constraints: fix only the run driver's blocked handling and resume
logic; do NOT change the blocked verdict itself, the contract lane, or the
state machine; must not break resume for non-blocked scenarios; `dart
analyze` with no new warnings.
