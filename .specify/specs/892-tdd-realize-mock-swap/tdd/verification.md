---
feature: 892-tdd-realize-mock-swap
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 85eec378
behaviors: 24
proven: 24
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 4/4 caught (deliberate mutants, sampled — no mutation tool in the stack profile)
mutants_survived: 0 (one survivor found and remediated in-run: U12c now pins the boundary)
suite: 28 passed, 0 failed (feature scope, ~1s); full repo chunked suite 67 chunks, ~2487 passed, 0 failed
---

# TDD Verification: 892-tdd-realize-mock-swap (spec 913 — zfa tdd realize)

**Verdict: PASS_WITH_GAPS.** Every behavior has recorded red evidence
corroborated by test-first git commits, no HIGH smells, and all five success
criteria are covered through the real CLI entry point. The gaps are the
sampling scope of mutation testing and the untested production subprocess
paths; both are listed below. Disclosure per Hard Rule 2: this audit was run
by the same session that wrote the tests and the implementation — it
re-read every file from disk for the smell pass, but it is not an
independent-context audit.

## Test-first evidence

The cycle log (`tdd/cycle-log.md`) records a red entry per behavior group
(stub-raised `UnimplementedError` / assertion failures) and a green entry
after implementation, hash-chained per behavior. Git history corroborates
the order: each task has a `…RED — failing tests` commit that lands tests
plus throwing stubs BEFORE the `…GREEN` implementation commit.

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| A1 | PROVEN | red `28756be…` (A1,A2,A6 group) recorded; `faa1fa2e` RED commit precedes `5063133d` GREEN; era-evidence extension red `b766d1c6` precedes `5af4e316` |
| A2 | PROVEN | same RED/GREEN commit pair; refusal asserted before implementation |
| A3, A3b | PROVEN | red `88aafeb7`; `4ef76526` RED precedes `2952bad9` GREEN (block + rollback + side attribution) |
| A4a, A4b | PROVEN | red `31a1455f`; `8b49daf5` RED precedes `384ae295` GREEN (drift block/pass + report) |
| A5 | PROVEN | red `0b0b5e30`; `332f1842` RED precedes `45a62512` GREEN (hand-delta block/gate + ledger) |
| A6 | PROVEN | same evidence as A1 (behavior-id target through the registry) |
| U1–U3 | PROVEN | red `e424d3e0`; stub commit precedes `5063133d` |
| U4–U7 | PROVEN | red `1ab5516d`; same order |
| U8–U10 | PROVEN | red `4a47d62c`; `4ef76526` precedes `2952bad9` |
| U11–U13 | PROVEN | red `5daba8d6`; `8b49daf5` precedes `384ae295` |
| U12c | PROVEN | red recorded under the deliberate mutant `drift < threshold` (`3b9a1823`), green after exact restore (`894ee522`) — mutant-driven red |
| U14–U16 | PROVEN | red `caaefb87`; `332f1842` precedes `45a62512` |
| U17, U18 | PROVEN | red `fe17cd72`; `38736b46` RED precedes `5af4e316` GREEN |

Weakened existing tests: none. The feature touched no pre-existing test
assertions; the formatter-only changes to pre-existing files were checked
(`git diff master --stat`) and carry no assertion edits.

## Findings

Ordered by severity. No HIGH findings. No remediation tasks were appended
for the LOWs; the single actionable finding from the mutant pass was
remediated in-run (see Mutation results) with its own red/green cycle.

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | The command-level tests always inject the suite runner and fixture driver; the production default paths (spawning real `dart test`, spawning `tool/realize_driver.dart`) are documented but never exercised in the fast tier — a driver/suite protocol regression would surface only in real projects | `lib/src/plugins/tdd/commands/realize_command.dart:412-455` |
| 2 | LOW | Test receipts hardcode `generatorVersion: '6.1.0'` | `test/plugins/tdd/commands/realize_command_test.dart:154` |
| 3 | LOW | Entity resolution from behavior descriptions relies on the `entity <Name>` planner convention; only the `create entity User` shape is pinned | `lib/src/plugins/tdd/commands/realize_command.dart:560-570` (A6 pins it) |

## Mutation results

No mutation tool is wired in the stack profile (see
`.specify/memory/tdd-profile.md`), so the rubric's deliberate-mutant
sampling was used on the four highest-risk behaviors: the two gate
verdicts (misattribution would mislead a merge decision), the drift
threshold comparison (a boundary off-by-one silently changes the gate),
and the nuance unreceipted class (a dropped branch silently legalizes
ungated hand-deltas). Sampled: 4 of 24 behaviors.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | ------- |
| contract verdict inversion (mock-red blamed on real impl) | U10, A3b | No | caught by U10 (`contract_gate_test.dart:79`) |
| drift `<=` → `<` (boundary off-by-one) | U12, A4 | **Yes, initially** | SURVIVED the pre-remediation suite; remediated by U12c (drift == threshold passes), red-recorded under the mutant, now caught |
| unreceipted hand-delta branch dropped | U16, A5 | No | caught by U16 (`nuance_receipts_test.dart:132`) |
| era dropped from the chain payload | U17 | No | caught by U17's era-changes-hash assertion (`era_tagged_log_test.dart:88`) |

Every mutant was restored exactly (sha-verified against git) and the full
feature suite re-run green after each restore.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| SC-1 MOCK-era suite stays green against the real binding | A1, A3, A3b, U8–U10 | Yes (A1/A3 drive the CLI entry point; only the process boundary is faked) |
| SC-2 Differential drift report with configurable threshold | A4a, A4b, U11–U13, U12c | Yes |
| SC-3 Hand-written deltas recorded with reason + diff-hash | A5, U14–U16 | Yes |
| SC-4 MOCKED → REAL transitions with era tags in cycle-log | A1 (era assertion), U17, U18 | Yes |
| SC-5 Mock-first realization is the default path | A1, U1 (absent state = MOCKED, never an error) | Yes |

Untested criteria: none. Tests tracing to nothing: none (A2/A6 trace to
the command contract CC-1, recorded in the test list's traceability
section).

## What was not audited

- Mutation was sampled (4 deliberate mutants on the highest-risk
  behaviors), not exhaustive; no mutation tool is configured for this
  repo, so the score is a sample, not a measurement.
- The production subprocess paths (the default `dart test` suite runner
  and the `tool/realize_driver.dart` spawn protocol) are not exercised in
  the fast tier — Finding 1.
- Performance and concurrency: no criterion, no test, not assessed. The
  contract gate runs the suite twice by design; wall-time impact on real
  projects was not measured.
- The audit was performed by the implementing session (Hard Rule 2
  disclosure above); a fresh-context re-audit would be stronger evidence.
