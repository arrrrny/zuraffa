---
feature: 070-ci-referee-provenance
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 1efa9a8a # short SHA audited
behaviors: 29
proven: 0
likely: 24
test_after: 5
no_test: 0
high_smells: 0
criteria_total: 15
criteria_covered: 15
mutation_score: 0 # no tool wired; 3 deliberate mutants, 3 caught (100% of sample)
mutants_survived: 0
suite: 37 passed, 0 failed, 10s (feature scope); 70-chunk fast suite: 63 passed / 5 skip / 0 failed
---

# TDD Verification: CI Referee + Provenance Dashboards

**Verdict: PASS_WITH_GAPS.** Every criterion in `spec.md` is covered by a
passing test, the discipline held red → green for six of eight cycles with
captured failure output, and all three deliberate mutants on the
highest-risk behaviors (publishing gate, drift detection, excerpt limits)
were caught. The gaps: five behaviors (U12–U16) have red entries whose
`output:` block is narrative rather than captured runner output, and the
entire feature landed as a single commit, so git history cannot
independently corroborate test-first ordering for any behavior — the
cycle log is the only ordering evidence.

## Test-first evidence

The audit was not independent: the implementing session also recorded the
cycle-log evidence being graded here, per the hard rules this is disclosed
rather than hidden. Where the sources disagree, history would win over
the log; here history is silent (one commit, tests and sources together).

| Behavior | Class       | Evidence                                                                                                    |
| -------- | ----------- | ----------------------------------------------------------------------------------------------------------- |
| A1–A3    | LIKELY      | cycle 1 red recorded with captured assertion failures (`Actual: ''`); history single-commit                 |
| U1–U6    | LIKELY      | cycle 2 red recorded with captured assertion failures (StateError, empty list); history single-commit       |
| A4–A6    | LIKELY      | cycle 3 red recorded with captured UnimplementedError output; history single-commit                         |
| A7–A10   | LIKELY      | cycle 4 red recorded with captured UnimplementedError output; history single-commit                         |
| A11–A13  | LIKELY      | cycle 5 red recorded with captured UnimplementedError output; history single-commit                         |
| U7–U11   | LIKELY      | cycle 6 red recorded with captured UnimplementedError output; history single-commit                         |
| U12–U13  | TEST_AFTER  | red entry claims compile error but the `output:` block is narrative, not a captured run                     |
| U14–U16  | TEST_AFTER  | red entry claims compile error but the `output:` block is narrative, not a captured run                     |

## Findings

Ordered by severity, each with evidence and the fix.

| #  | Severity | Finding                                                                                        | Evidence                                                            |
| -- | -------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1  | MED      | U12–U16 red evidence is a claimed compile error with no captured runner output                  | `specs/070-ci-referee-provenance/tdd/cycle-log.md` (U12–U16 red)    |
| 2  | LOW      | `writeFeature`-style fixture builders duplicated across four test files instead of a helper     | `test/plugins/tdd/services/ci_referee/*_test.dart`                  |
| 3  | LOW      | Awkward path construction `'specs/f-hand/ttd/cycle-log.md'.replaceAll('ttd', 'tdd')`            | `test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart:127` |
| 4  | LOW      | Concurrent-receipt-writes edge covered only implicitly (latest-wins index), no two-receipt test | `feature_provenance_reader.dart` `latestByPath`                     |

## Mutation results

No mutation tool is wired (see `.specify/memory/tdd-profile.md`), so
Phase 4 used deliberate mutants on the highest-risk behaviors. Each
mutant was restored exactly and the suite re-run green after every
restore (confirmed: `git diff` clean, 33/33 passing).

| Mutant                                                       | Behavior | Survived | Judgment                                            |
| ------------------------------------------------------------ | -------- | -------- | --------------------------------------------------- |
| `publishing_gate.dart` intermediate-state guard disabled      | A10, U15 | No       | Caught by 3 tests — FR-015/SC-003 pinned            |
| `feature_provenance_reader.dart` drift detection returns true | U5       | No       | Caught — hand-delta receipts pinned                 |
| `failure_artifacts.dart` `maxExcerptLines` 20 → 100           | A11      | No       | Caught — excerpt ceiling pinned (US4.SC-004)        |

Scope: 3 mutants on the highest-risk behaviors, not the whole module —
deliberate sampling, not exhaustive mutation.

## Traceability

| Criterion | Tests                            | End to end                                     |
| --------- | -------------------------------- | ---------------------------------------------- |
| FR-001    | U7, U14                          | Yes (`referee run` through CliRunner)          |
| FR-002    | A1, A2, U14                      | Yes                                            |
| FR-003    | A4, A5, U16                      | Yes (`referee rollup`)                         |
| FR-004    | A7, U15                          | Yes (`referee gate` exit codes)                |
| FR-005    | A8, A9, U15                      | Yes                                            |
| FR-006    | A11                              | Yes                                            |
| FR-007    | A12                              | Yes                                            |
| FR-008    | A3, U14 (doc-only)               | Yes (`--changed-files` path)                   |
| FR-009    | U4, A4 (f-hand)                  | Yes                                            |
| FR-010    | U8                               | Yes (run-state resume)                         |
| FR-011    | A13                              | Yes                                            |
| FR-012    | A6, U16                          | Yes (archive dir on disk)                      |
| FR-013    | U9, U14                          | Yes                                            |
| FR-014    | U10, U14                         | Yes                                            |
| FR-015    | A10, U3                          | Yes                                            |

Untested criteria: none. Tests tracing to nothing: none (all 29
behaviors trace to a criterion; edge cases shared/empty/interruption
are placed on U6/U11/U8).

## What was not audited

Say it plainly, every run.

- The GitHub posting path was graded only through the injected
  `RecordingClient` fake (U12); no live API call was made or audited.
- Mutation was a 3-mutant deliberate sample on the highest-risk
  behaviors, not the whole module; test strength is recorded as
  unmeasured beyond that sample.
- The slow tiers (`slow`-tagged integration/property/benchmark tests)
  were excluded per the repo's fast-suite profile; the 5 skip-chunks
  (test/benchmark, test/core/dependencies, test/integration,
  test/plugins/tdd/scenarios, test/property) are pre-existing
  all-slow folders, not coverage gaps introduced by this feature.
- Performance and the ≤10% golden-workflow overhead target (SC-005)
  were not measured: no criterion-level benchmark exists for the
  referee's read-only pass, and the corpus fixtures in tests are too
  small to extrapolate timing from (9.9 s for the full feature suite).
- The 2-minute verdict deadline (SC-001) is a CI deployment property;
  only the local rendering path was exercised.
