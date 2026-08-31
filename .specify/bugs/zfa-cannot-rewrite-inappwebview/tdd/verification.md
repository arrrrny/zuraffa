---
feature: zfa-cannot-rewrite-inappwebview
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fa2c501b # short SHA audited (branch HEAD; fix uncommitted at audit time)
behaviors: 5
proven: 0
likely: 5
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool in profile; deliberate mutants 2/2 caught, 1 equivalent judged
mutants_survived: 0
suite: 5 passed, 0 failed (scoped doc tests, <1s); chunked fast suite 59/59 executed chunks green
---

# TDD Verification: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

**Verdict: PASS_WITH_GAPS.** All five behaviors are `LIKELY` (the cycle log
records the red command and output, but the branch is uncommitted so git
cannot corroborate test-before-fix ordering), no `HIGH` smells, all three
acceptance criteria reach tests that read the real shipped doc files, and
both sampled deliberate mutants were caught and restored exactly.

The audit was run by the same session that wrote the tests (Hard Rule 2):
every file was re-read cold from disk before grading, and the mutant runs
were executed fresh during the audit, but the judgment is not independent.

## Test-first evidence

| Behavior | Class  | Evidence                                                                   |
| -------- | ------ | -------------------------------------------------------------------------- |
| A1       | LIKELY | cycle 1 records the red (`Which: does not contain 'Zuraffa apps'`); branch uncommitted, no git ordering |
| A2       | LIKELY | cycle 1 records the red (`does not rewrite existing non-Zuraffa`); same ordering caveat |
| A3       | LIKELY | cycle 1 records the red (`not a malfunction of the CLI`); same ordering caveat |
| A4       | LIKELY | cycle 1 records the red (`file a feature request`); same ordering caveat |
| A5       | LIKELY | cycle 1 records the red (`Zuraffa apps` / `non-Zuraffa` in README.md); same ordering caveat |

Diff of the change against existing tests: none. The diff adds one test
file and touches no existing test, no assertion, no tag, no
`dart_test.yaml`/coverage/mutation config (verified via `git status` /
`git diff`: only `CLI_GUIDE.md` and `README.md` modified, both additive
inserts; no deletions anywhere). No skipped, pending, or filtered-out
existing test.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | The guard does not run in CI's fast tier: the test is `regression,slow` tagged (matching the folder's uniform convention and the direct precedent `docs_command_consistency_test.dart`), and CI runs `dart test test --exclude-tags flutter` with `exclude_tags: slow` from `dart_test.yaml` — so the scope contract is only enforced when someone runs the regression preset. This is the same gap the precedent has; recorded, not fixed (one-bug PR, minimal change). | `test/regression/issue_477_zfa_scope_docs_test.dart:1`, `.github/workflows/ci.yaml:34`, `dart_test.yaml:52` |
| 2 | MED | A5 pins the README contract more weakly than A2 pins the guide: it asserts `contains('Zuraffa apps')` + `contains('non-Zuraffa')` rather than the full limitation sentence. Empirically, deleting only the README's "does not rewrite existing non-Zuraffa" line leaves A5 green because the next sentence ("Rewriting a non-Zuraffa plugin stays hand-written work") still conveys the behavior — judged an equivalent mutant below, but a future rewording that keeps the word "non-Zuraffa" while dropping the substance would survive. | `test/regression/issue_477_zfa_scope_docs_test.dart:86-96` |
| 3 | LOW | String-containment contracts are rewording-fragile by design: any prose edit that breaks a pinned phrase across a markdown line wrap flips the test red (this happened mid-cycle and was fixed by re-wrapping, not by weakening the assertion). Acceptable for a doc contract, worth knowing. | cycle-log.md "Mid-cycle note" |
| 4 | LOW | Mystery-guest-adjacent: the test reads on-disk repo docs via `findProjectRoot()` — the established helper for this test kind, deterministic and CWD-independent, so the standard repository judgment is "not a smell"; noted only because the profile's Helpers section does not list `project_root.dart` explicitly. | `test/helpers/project_root.dart`, `test/regression/docs_command_consistency_test.dart:7` |

## Mutation results

No mutation tool in the profile; deliberate mutants on the two
highest-risk behaviors (one per changed doc file), per the rubric's
fallback procedure. Every mutant was restored exactly (`diff` against a
pre-mutant backup was empty) and the suite was re-run green after each
restore.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| Removed the limitation sentence "`zfa` does not rewrite existing non-Zuraffa Flutter packages or plugins." from `CLI_GUIDE.md` (line 20) | A2 | No | Test went RED (matcher miss on `does not rewrite existing non-Zuraffa`), restored, green |
| Deleted the entire README "Scope" paragraph (lines 44-51) | A5 | No | Test went RED (both `Zuraffa apps` and `non-Zuraffa` missing), restored, green |
| Deleted only README line 47 (the limitation sentence, keeping "Rewriting a non-Zuraffa plugin stays hand-written work") | A5 | Yes | Equivalent mutant: the behavior (README states non-Zuraffa packages are not rewritable) is still conveyed by the surviving sentence; reported as finding #2 rather than as a bug the suite missed |

Two behaviors sampled (A2, A5); A1, A3, A4 were not mutated — A1/A3/A4 are
same-mechanism string contracts in the same file as A2, whose mutant was
caught. Not exhaustive.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| AC1 (guide states Zuraffa-apps scope) | `A1` | Yes — reads the shipped `CLI_GUIDE.md` |
| AC2 (guide + README state the non-Zuraffa limit and expected doctor output) | `A2`, `A3`, `A5` | Yes — reads both shipped doc files |
| AC3 (guide routes plugin rewrites to a feature request) | `A4` | Yes — reads the shipped `CLI_GUIDE.md` |

Untested criteria: none. Tests tracing to nothing: none. All five claimed
tests exist and run under `dart test --preset=regression` (5/5 green this
session). The "real entry point" for a doc contract is the doc file itself;
no doubles are possible at this boundary, so the end-to-end check is
satisfied by reading the files users read.

## What was not audited

- Git history ordering: the fix was uncommitted at audit time, so `PROVEN`
  could not be established for any behavior; all five are `LIKELY`. The
  cycle log records the red command and output for each.
- Mutation was not tool-measured (`mutation_test` is wired for the TDD
  plugin scope in `mutation-test.xml`, not for doc contracts); deliberate
  mutants sampled 2 of 5 behaviors, plus one equivalent-mutant judgment.
- The full slow tiers (regression/integration/property/benchmark presets
  beyond the two doc tests) were not run: per the repo's TDD profile and
  `dart_test.yaml` they spawn temp projects with `dart pub get` +
  `build_runner` and do not fit this cloud agent's disk budget. The fast
  suite ran chunked (59/59 executed chunks green; 5 all-slow folders exit
  79 "No tests ran" — verified pre-existing with the fix stashed).
- Coverage tooling: not run (opt-in per profile, no gate).
- No `plan.md` or `tasks.md` exists for this bug, so Phase 7 remediation
  tasks were not appended; the findings worth acting on (CI gap, A5
  strength) are recorded above and in `test.md`'s residual risks.
- Website docs (`website/docs/`) were not checked for a matching scope
  statement; the spec scoped the fix to `CLI_GUIDE.md` and `README.md`.
