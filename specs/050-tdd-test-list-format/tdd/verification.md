---
feature: 050-tdd-test-list-format
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 767d4e83 # short SHA audited
behaviors: 19
proven: 12
likely: 0
test_after: 7
no_test: 0
high_smells: 0
criteria_total: 8
criteria_covered: 8
mutation_score: unmeasured # no mutation tool wired; 8 deliberate mutants sampled, 8 caught, 0 survived
mutants_survived: 0
suite: 227 passed, 0 failed (fast TDD tier, ~9s) / 20 passed, 0 failed (slow driver+scenario: run_command_test + sc_019, ~31s) / 33 chunked fast-suite chunks passed, 3 pre-existing "No tests ran" chunks (identical on pristine master, proven via worktree)
---

# TDD Verification: TDD plan↔gen test-list format contract

**Verdict: FAIL.** The rubric's fail-closed table fails any feature with a
`TEST_AFTER` behavior, and 7 of 19 behaviors (U1, U2, U3, U4, U6, U8, A6) are
mechanically test-after: their unit tests landed in commits `0827dbb3` /
`b46d074b`, one or more commits AFTER the reader source that satisfies them
(`4eba2f75` / `0827dbb3`). The mitigating evidence is strong and recorded —
the same code path carries a PROVEN acceptance-level red (A4, cycle 1), every
one of the 7 has a caught deliberate mutant, no HIGH smells, no weakened
assertions, all 8 criteria covered end-to-end, zero surviving mutants — but
the ordering evidence the rubric demands per behavior does not exist and
cannot be manufactured after the fact.

## Audit independence disclosure

The same session authored the code and ran this audit. Mitigations applied:
every changed test and source file was re-read cold for this report; every
mechanical check (suite runs, history corroboration, deliberate mutants,
restore verification) was executed from the live tree; the git history was
walked per behavior to corroborate or contradict the cycle log. The
pre-existing-chunk claim was proven by running the same 3 chunks on a
pristine master worktree.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ------ | -------- |
| A4 | PROVEN | cycle 1 red recorded verbatim (gen exits `malformed test list — line 7 ... found 6`); `4eba2f75` adds test + source together |
| U7 | PROVEN | credited by A4's red-first test, which asserts the adapter contract (`source_criterion: US1.AC1` from a 6-column row) |
| U9 | PROVEN | cycle 8 red recorded verbatim (`unknown state "PROVEN"` at specs/044 line 105); `b46d074b` adds test + PROVEN-mapping source together |
| U10 | PROVEN | cycle 6 red recorded verbatim (`found 7` on the escaped-pipe row); `0827dbb3` adds test + `_splitRow` source together |
| U11 | PROVEN | cycle 8 red recorded (same failure); `b46d074b` adds test + source together |
| A1, A2, A3, A5, A7, A8, U5 | PROVEN (landed) | credited at plan time from master's #617 remediation (`74c132db`, test+source same commit, its own verification at `.specify/bugs/tdd-plan-gen-test-list-format-mismatch/tdd/verification.md`); each re-confirmed green in this run (227 fast + 33 chunks) |
| U1, U2, U4, U6 | TEST_AFTER | tests landed `0827dbb3`, source landed `4eba2f75` (cycle 1's acceptance-driven green). Cycle log records the first-run pass honestly per the playbook's first-run rule, plus a caught deliberate mutant each: forced-unit (U1 failed `Expected acceptance / Actual unit`), forced-acceptance (U2), orphan-guard drop (U4), shrunk shape set (U6 failed on the `property` row) |
| U3, U8, A6 | TEST_AFTER | tests landed `b46d074b`, sources landed `4eba2f75`/`0827dbb3`. Strength proven: warn-per-row mutant (U3 failed "once per file, not per row"); branch-disabled mutant (U8 and A6 both restored the `result=runner-error` front-door failure). A6 additionally carries the LIVE pre-implementation repro in the baseline entry (`zfa tdd run 049-tdd-run` -> runner-error, recorded before any change) |

### What the diff did to tests that already existed

Reported with before/after per the rubric, whatever the reason:

- `test/plugins/tdd/services/test_list_reader_test.dart` — the U3 malformed-row
  fixture (line ~104) and the 617-shim unusable-kind fixture (line ~222) were
  re-pointed from kind cell `example` to `banana` BEFORE the implementation
  landed (pre-cycle step, recorded in cycle 1). Before: `| U2 | six column row |
  FR-002 | example | PENDING |  |` — After: same row with `banana`. The
  assertion is unchanged in strength (throws `TestListReadException` naming
  the line and the row); the fixture changed because FR-007 moved `example`
  from malformed to shim-accepted. This is a contract change with its own
  behaviors (U4/U5), not a weakening. Both tests stayed green before and
  after the re-point.

## Findings

Ordered by severity, each with evidence and the fix.

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | HIGH (blocking, verdict) | 7 behaviors are TEST_AFTER: their unit tests landed after the shared reader change that satisfies them. The loop drove the acceptance behavior first (A4 red -> implementation), then pinned the units — the outside-in trade — leaving no per-behavior red for U1/U2/U3/U4/U6/U8/A6 | `git log --name-only 4eba2f75 0827dbb3 b46d074b`; cycle-log cycles 2-5, 7, 9-10 all record "red: none recorded — passed on FIRST run" |
| 2 | MED | U9's regression guard reads the repo's real `specs/044-049` files — intentional (the behavior IS about those files), but a future edit to those lists changes the test's inputs invisibly | `test_list_reader_test.dart` (`050: the repo's real specs/044-049 ...`) |
| 3 | MED | sc_019/U3 asserts substrings of the deprecation note's prose — coupled to the warning's wording (justified: FR-009 requires the note to name the canonical format and producing command) | `sc_019_legacy_dialect_migration_test.dart` |
| 4 | LOW | U6 sweeps the five extension shapes in one loop-structured test; every iteration asserts the same three properties with per-shape reasons (not a conditional skip, but one failure reports only one shape) | `test_list_reader_test.dart` (`050: every extension test shape is accepted`) |

## Mutation results

No mutation tool is wired (profile: "none wired in CI"); deliberate mutants
were sampled on the highest-risk behaviors — the ones the acceptance
criteria depend on. 8 mutants, 8 caught, 0 survived. Every mutant was
restored exactly and the suite re-run green after each restore.

| Mutant | Behavior(s) that caught it | Survived | Judgment |
| ------ | -------------------------- | -------- | -------- |
| extension branch ignores section header (forced unit) | U1 | No | kind-from-section is pinned |
| extension branch forced acceptance (mirror) | U2 | No | mirror side pinned |
| orphan guard dropped (`kind ?? unit`) | U4 | No | FR-005 misfire-stop pinned |
| accepted shape set shrunk to `{'example'}` | U6 | No | all five shapes pinned |
| row split reverted to naive `split('|')` | U10 | No | escaped-pipe handling pinned |
| warn-per-row instead of once-per-file | U3 | No | FR-009 once-per-file pinned |
| extension branch disabled (`false && ...`) | U8, A6, U9, U1, U2, U4, U6 | No | the feature's whole surface fails at the front door |
| (application note) first attempt at the shrunk-set mutant silently failed to apply (string mismatch) and the suite stayed green — caught because the failure was required to be observed; re-applied correctly | — | n/a | recorded in cycle 5; the check on the check |

Also observed live: `dart run bin/zfa.dart tdd gen U15 --feature
049-tdd-run --dry-run` resolves the repo's real escaped-pipe row
(`behavior_id: U15`, `source_criterion: FR-002`) — the pre-feature live
repro of both the dialect stop and the pipe mis-split is recorded in the
baseline entry and cycle 6.

## Traceability

| Criterion | Behaviors / tests | End to end |
| --------- | ----------------- | ---------- |
| US1.AC1 (plan->run completes) | A1 via `sc_018_plan_run_loop_e2e_test.dart` (real temp project, real pipeline) | Yes |
| US1.AC2 (gen resolves plan rows, kind from section, default target) | A2 via `plan_gen_contract_test.dart` | Yes |
| US1.AC3 (unknown id non-zero) | A3 via `gen_command_test.dart:178` | Yes |
| US2.AC1 (extension dialect accepted + note) | A4 (gen, CLI) + U8 (run, CLI + fake steps) + U3 (note, real subprocess) | Yes |
| US2.AC2 (acceptance/unit cell wins) | A5 via `617-shim: deprecated 6-column rows parse with kind from the cell` + sc_019/U3's mixed list | Yes |
| US2.AC3 (repo's own 049 list re-readable) | A6 via `sc_019` (real CLI on the real list bytes) + U9 (reader, real files) | Yes |
| US3.AC1 (malformed stops naming the line) | A7 via reader guards + the baseline live repro of the CLI-level stop | Yes |
| US3.AC2 (CI front-door e2e) | A8 via `sc_018` | Yes |

Untested criteria: none. Tests tracing to nothing: none (every `traces`
value resolves to US*.AC*, FR-*, or SC-* in `spec.md`).

## Suite state at verified_at

- `dart analyze` (full repo): no issues.
- `dart test test/plugins/tdd/` (fast tier): 227 passed, 0 failed.
- `dart test --preset=all test/plugins/tdd/run_command_test.dart
  test/plugins/tdd/scenarios/sc_019_legacy_dialect_migration_test.dart`:
  20 passed, 0 failed.
- `tools/run_tests_chunked.sh`: 33 chunks "All tests passed!", 3 chunks
  "No tests ran." (`test/benchmark`, `test/core/dependencies`,
  `test/integration`) — **pre-existing and unrelated**: proven identical
  (exit 79, "No tests ran.") on a pristine master worktree; those folders
  hold only slow/flutter-tagged files the fast tier excludes, and the branch
  changes 0 lines under them.
- `dart format .`: 0 files changed.

## What was not audited

- Mutation strength is sampled (8 deliberate mutants), not measured — no
  mutation tool is wired in CI (profile states this; the repo's
  `mutation-test.xml` scope predates this feature and was not re-scoped).
- Coverage was not run (opt-in in this repo, not a gate).
- The audit was run by the same session that wrote the tests (disclosed
  above); no fresh-context subagent was available for the smell pass.
- Slow tiers beyond the TDD plugin (`--preset=all` across the whole repo)
  were not run on this small disk — the chunked fast tier plus the two
  TDD-plugin slow files were the audit scope, per the profile's guidance.
- The landed #617 core's own evidence (A1/A2/A3/A5/A7/A8/U5) was re-confirmed
  green but not re-audited; its audit lives with the bug workflow.

## Verdict rationale, read honestly

The verdict is FAIL because the rubric is deliberately fail-closed on
ordering evidence, and this feature traded per-unit reds for an
acceptance-first red. What stands in the feature's favor — and is recorded,
not claimed: a PROVEN acceptance red covering the shared code path; 8/8
caught mutants including one that fails the feature's entire surface; zero
HIGH smells; zero weakened assertions; all criteria covered end-to-end; the
suite, analyze, format and chunked gates all green; and a cycle log that
records every first-run pass and every mutant honestly rather than
fabricating reds. A re-drive of the 7 behaviors from a reverted
implementation would manufacture reds with no additional evidentiary value
(the deliberate mutants already record exactly that failure mode, per
behavior), and was deliberately not performed.
