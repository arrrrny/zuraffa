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

## Cycle 1: A4 gen resolves an id from a hand-written 6-column extension-dialect list

- test: `test/plugins/tdd/commands/plan_gen_contract_test.dart::A4/050: gen resolves an id from a hand-written 6-column extension-dialect list (the 046/049 shape)` (new)
- red: `dart test test/plugins/tdd/commands/plan_gen_contract_test.dart --plain-name "A4/050: gen resolves an id from a hand-written 6-column extension-dialect list (the 046/049 shape)"` ->
  `❌ Error: Bad state: zfa tdd gen: malformed test list — test-list.md line 7: expected 4 columns (id/behavior/traces/state), found 6: "| A1 | Honestly-red behavior run: ... | US1.AC1 | example | DONE | sc_001_certifies_honest_red_test.dart::A1 |"` (1 failed; run against pre-implementation code)
- green: `lib/src/plugins/tdd/services/test_list_reader.dart` `_parseDataRow` gained the extension-dialect branch (spec 050 FR-007): a 6-column row whose kind cell is an extension test shape (`example`/`property`/`contract`/`approval`/`characterization`) resolves its kind from the section header (required — orphaned rows stay malformed), treats the last cell as a test reference (path-like/empty -> `subject_<snake-id>`), and returns `deprecated: true` (the one-per-file stderr note). Suite `dart test test/plugins/tdd/` -> 221 passed, 0 failed.
- refactor: none needed — one branch mirroring the existing dialect-1 shape, plus `_isExtensionTestShape` beside `_kindFromCell`
- pre-cycle test change (stated reason, before implementation): the U3 and 617-shim malformed-row fixtures in `test_list_reader_test.dart` were re-pointed from kind cell `example` to `banana` — FR-007 moves `example` from malformed to shim-accepted, so the FR-005 guard needed a shape that STAYS malformed; both re-pointed tests stayed green before and after the change (T005)
- follow-up: mid-cycle discovery — the live repro surfaced specs/049 U15 (`outcome=clean\|refactored`), a markdown-escaped pipe inside a cell that naive `split('|')` counts as a 7th column; appended U10 to the test list for its own cycle
- commit: pending (recorded post-commit)
