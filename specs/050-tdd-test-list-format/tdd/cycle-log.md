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
- commit: `4eba2f75`

## Cycle 2: U1 extension-dialect row in the outer section resolves acceptance kind + default target

- test: `test/plugins/tdd/services/test_list_reader_test.dart::050: an extension-dialect row in the outer section resolves acceptance kind and the default target` (new)
- red: none recorded — the test passed on FIRST run: the behavior was implemented by cycle 1's green (the shared reader branch serves A4 and U1 alike). Per the playbook's first-run rule, strength was proven with a deliberate mutant instead (below)
- mutant: forced `kind: BehaviorKind.unit` in the extension branch (ignore the section header) -> this test failed `Expected: BehaviorKind:<BehaviorKind.acceptance> Actual: BehaviorKind:<BehaviorKind.unit>`; restored exactly; reader suite -> 16 passed, 0 failed
- green: (already green; no code change this cycle) suite `dart test test/plugins/tdd/` -> 226 passed, 0 failed
- refactor: none
- commit: pending

## Cycle 3: U2 extension-dialect row in the inner section resolves unit kind

- test: `test/plugins/tdd/services/test_list_reader_test.dart::050: an extension-dialect row in the inner section resolves unit kind and the default target` (new)
- red: none recorded — passed on FIRST run (same shared branch as U1); mirror mutant applied
- mutant: forced `kind: BehaviorKind.acceptance` in the extension branch -> this test failed `Expected: BehaviorKind:<BehaviorKind.unit> Actual: BehaviorKind:<BehaviorKind.acceptance>`; restored exactly; suite green
- green: no code change; suite 226 passed, 0 failed
- refactor: none
- commit: pending

## Cycle 4: U4 extension-dialect row outside any section stays malformed

- test: `test/plugins/tdd/services/test_list_reader_test.dart::050: an extension-dialect row outside any section stays malformed` (new)
- red: none for the guard itself — the guard already worked (implemented with cycle 1). The FIRST run failed on a bug in MY test: I expected `line 6` but the fixture row sits on line 5; the reader's error verbatim was `test-list.md line 5: table row outside an outer/inner loop behavior section: "| U1 | orphaned extension row | FR-005 | example | PENDING |  |"` (proof the guard fired); expectation corrected to line 5
- mutant: replaced the orphan guard with `kind ?? BehaviorKind.unit` (orphans allowed) -> this test failed (`Expected: throws TestListReadException ... Actual: Future completed`); restored exactly; suite green
- green: no code change; suite 226 passed, 0 failed
- refactor: none
- commit: pending

## Cycle 5: U6 every extension test shape is accepted

- test: `test/plugins/tdd/services/test_list_reader_test.dart::050: every extension test shape is accepted` (new; loops example/property/contract/approval/characterization)
- red: none recorded — passed on FIRST run
- mutant: shrunk the accepted set to `{'example'}` -> this test failed `test-list.md line 5: expected 4 columns (id/behavior/traces/state), found 6: "| U1 | shape property row | FR-007 | property | PENDING | t.dart::U1 |"`. NOTE (honesty): the FIRST application of this mutant silently failed to apply (the replacement string did not match the formatted source) and the suite stayed green — caught precisely because the playbook requires OBSERVING the mutant failure, re-applied against the real source shape, and then observed the failure; restored exactly; suite green
- green: no code change; suite 226 passed, 0 failed
- refactor: none
- commit: pending

## Cycle 6: U10 markdown-escaped pipes stay cell content (specs/049 U15)

- test: `test/plugins/tdd/services/test_list_reader_test.dart::050: markdown-escaped pipes in cells stay cell content (specs/049 U15 shape)` (new; fixture is the verbatim specs/049 line-72 row)
- red: `dart test test/plugins/tdd/services/test_list_reader_test.dart --plain-name "050: markdown-escaped pipes in cells stay cell content (specs/049 U15 shape)"` ->
  `test-list.md line 5: expected 4 columns (id/behavior/traces/state), found 7: "| U15 | refactor succeeds only on exit 0 AND `+"`out"+"come=clean\\|refactored` | FR-002 | example | DONE | ...`"+` (1 failed — discovered LIVE: `dart run bin/zfa.dart tdd run 049-tdd-run` stopped at this row after cycle 1)
- green: `test_list_reader.dart` row splitting moved from `split('|')` to `_splitRow` — markdown's `\|` is unescaped to cell content, never a delimiter; suite `dart test test/plugins/tdd/` -> 226 passed, 0 failed. Live re-probe: `dart run bin/zfa.dart tdd gen U15 --feature 049-tdd-run --dry-run` -> `behavior_id: U15 / source_criterion: FR-002 / ownership: planned/planned` (dry-run; no files written)
- mutant: reverted `_splitRow` call to `trimmed.split('|')` -> this test failed with the same `found 7` malformed error; restored exactly; suite green
- refactor: none — `_splitRow` sits beside the other static cell helpers
- commit: pending
