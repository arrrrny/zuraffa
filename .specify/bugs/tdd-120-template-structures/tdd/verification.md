---
feature: tdd-120-template-structures
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 224b4c1a
behaviors: 14
proven: 9
likely: 0
test_after: 0
no_test: 0
not_applicable: 5
high_smells: 0
criteria_total: 12
criteria_covered: 12
mutation_score: null # no mutation tool in profile; deliberate mutants: 4/4 caught
mutants_survived: 0
suite: 731 passed, 1 skipped, 0 failed (3m31s)
---

# TDD Verification: tdd-120-template-structures (issue #919)

**Verdict: PASS_WITH_GAPS.** Discipline holds (9 PROVEN via recorded reds +
history, 5 control/characterization behaviors mutant-validated), every
acceptance criterion has a CLI-level test, no HIGH smells. Gaps: the audit is
not independent (same session wrote the tests; smell pass delegated to a
fresh-context subagent, whose single MED finding was vetted line-by-line), and
mutation evidence comes from 4 deliberate mutants rather than a tool (the
profile has none).

## Independence statement

This audit was run by the same session that drove the red-green-refactor loop.
The catalogued smell pass was delegated to a fresh-context subagent (rubric +
profile + exemplars + helpers handed over, findings only), and every cited line
was re-opened by the auditor before inclusion. Test-first and traceability
evidence were re-read cold from the artifacts.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| A1 | PROVEN | cycle 1 red recorded (command + `Which: does not contain ...`); `79ec0bc6` adds test + source together; deliberate mutant (purpose dropped) caught |
| A2 | NOT_APPLICABLE | pre-existing plan_gen_contract bug-829 coverage retained; fixtures gained the marker in test-only commit `8e065358`, assertions unchanged |
| A3 | NOT_APPLICABLE | existing lenient `readEntities` seam captured; test fixture path bug fixed (`2561447e`); deliberate mutant (fields read from purpose column) caught |
| A4 | PROVEN | cycle 3 red recorded; tests predate gate source |
| A5 | PROVEN | cycle 3 red recorded; tests predate gate source |
| A6 | NOT_APPLICABLE | control (known version accepted); deliberate mutant (gate rejecting `zuraffa-1.0`) caught |
| A7 | PROVEN | red recorded (`no ## External dependencies rendered`); tests predate `9f31ca29` |
| A8 | PROVEN | red recorded (`no ## Layer contracts rendered`); tests predate `9f31ca29` |
| A9 | PROVEN | red recorded (`no exit 2 — Hive reference uncaught`); tests predate `71473db8` |
| A10 | NOT_APPLICABLE | pre-existing no-entities coverage retained; marker-adopted fixture only |
| A11 | PROVEN | red recorded at suite level (`bullets ignored after the table`); closed by A1's patch, logged |
| A12 | NOT_APPLICABLE | control (no-externals must not fire); deliberate mutant (lint fires on every statement) caught |
| A13 | PROVEN | red recorded (StateError/no-acceptance path); tests predate gate source |
| A14 | PROVEN | reader-side unresolved-symbol red recorded (cycle 6); `d71cd571` adds test + source together; CLI-side red recorded earlier |

## Findings

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | A14's CLI test asserts both the dependencies and layer-contract artifact sections in one test (eager) — two bugs could be conflated in the failure name | `test/plugins/tdd/bug_919_template_structures_test.dart:415-454` (comment at :444 already splits the reader side out) |

Vetted against the changed existing tests: no assertions removed, loosened, or
renamed; additions only (marker lines, one declared dependency row). No skipped/pending/excluded tests introduced.

Tasks consistency: T001-T020 ticked; behavior ids A1-A14 all DONE on the list;
no ticked task references a non-DONE behavior; no DONE behavior lacks a ticked
task that names it.

## Mutation results

No mutation tool in the profile — deliberate-mutant sample (4):

| Mutant | Behavior | Caught |
| ------ | -------- | ------ |
| `test_list_reader.dart` fields read from `cells[3]` (purpose column) | A3 | Yes |
| `spec_parser.dart` `knownTemplateVersions` = `{'zuraffa-9.9'}` | A6 | Yes |
| `plan_command.dart` lint fires on every statement | A12 | Yes |
| `spec_parser.dart` table rows lose the purpose capture | A1 | Yes |

All restored exactly and re-verified green (suite run after each restore).

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| US1-AC1 (table entities → artifact) | A1, A3 | Yes (CliRunner) |
| US1-AC2 (legacy bullets unchanged) | A2 | Yes |
| US1-AC3 (phase-0 seam) | A3 | Yes |
| US2-AC1 (missing marker → exit 3) | A4 | Yes |
| US2-AC2 (unknown version → exit 3) | A5 | Yes |
| US2-AC3 (zuraffa-1.0 proceeds) | A6 | Yes |
| US3-AC1 (deps table → artifact) | A7, A14 | Yes |
| US3-AC2 (layer contracts → artifact) | A8, A14 | Yes |
| US3-AC3 (undeclared external → exit 2) | A9 | Yes |
| Edge 1 (no entities section) | A10 | Yes |
| Edge 2 (mixed table + bullets) | A11 | Yes |
| Edge 3 (no externals, no lint) | A12 | Yes |

FR-001..FR-009 all traced via the test list to A1/A3/A11, A2/A11, A4/A5/A6,
A7, A8, A4/A5/A6/A13, A9/A12, A7/A8, A14 respectively. Every claimed test file
exists and ran; 14/14 behaviors verified in the 731-green suite. Untested
criteria: none. Tests tracing to nothing: none.

## What was not audited

- Full-repo mutation: no tool in profile; deliberate mutants sampled 4
  high-risk behaviors only (A1, A3, A6, A12).
- Coverage run: profile marks coverage opt-in; not run.
- Performance/load: no criterion, no test, not assessed.
- The pre-existing fixture edits in bug_846/830/833/gen_contract were audited
  only as diffs (additions); their full suites beyond the 833-lint interaction
  were re-run green in the 731-suite.
- `verify_red_subdirectory_test.dart` (bug #679): passed on the final suite
  run, but its 75s child-timeout harness cap is known-fragile under machine
  load (observed timing out mid-session on a clean tree); not assessed beyond
  the passing run.
- Environment noise: one `subprocess_timeout_test` load flake observed and
  re-verified green in isolation.

## Next step

Feature TDD evidence is complete. Finding 1 (A14 eager test) is a MED
deferred item — see the remediation task below.