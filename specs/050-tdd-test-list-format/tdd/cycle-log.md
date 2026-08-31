# Cycle Log: TDD plan↔gen test-list format contract

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 220 passed, 0 failed (fast tier)
- commit: `b31a48a7` (master HEAD the branch started from; artifact-only
  commits 46fc55ce..12577b69 do not touch code, so the suite result stands)
- recorded: cycle 0, before any change
- note: master already carries the #617 core remediation (`74c132db`) — gen
  consumes the shared `TestListReader`, the 4-column plan format is
  canonical, sc_018 pins plan→run, and the 6-column `acceptance`/`unit`
  shim exists. The remaining repro this feature fixes (observed live on
  this branch, pre-implementation):
  - `dart run bin/zfa.dart tdd run 049-tdd-run` ->
    `zfa tdd run: test-list.md line 24: expected 4 columns
    (id/behavior/traces/state), found 6` ->
    `run: feature=049-tdd-run result=runner-error pending=0 red=0 green=0
    done=0`
  - `dart run bin/zfa.dart tdd gen A1 --feature 046-tdd-verify-red` ->
    `zfa tdd gen: test-list.md line 28: expected 4 columns
    (id/behavior/traces/state), found 6` (kind cell `example`)
