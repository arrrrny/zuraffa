---
feature: .specify/bugs/tdd-make-plan-build-false-negative (bug #737, pinned per bug extension TDD mode, branch audit)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 505969d4
behaviors: 4
proven: 4
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 3/3 caught # scope: _toleratedTerminalBuildFailure + the tolerated-path outcome in make_command.dart only, manual deliberate mutants
mutants_survived: 0
suite: "make_command_test +28 −2 (2 pre-existing, pristine-identical); bug-737 group +4; scenarios +38 −8 (pristine-identical failing files); consumers +78 −1 (pristine-identical); chunked fast suite: all runnable chunks passed; dart analyze: clean"
---

# TDD Verification: bug #737 — make plan's terminal build step false-negatives on a pre-existing red suite

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real (the skip-transition
test failed against the pre-fix code with the exact #737 signature —
`generation step failed at index 1` → `outcome=generation-error`, exit 1 — and
passes against the fix; the end-to-end CLI repro flipped from
`outcome=generation-error` to `outcome=skipped` on the same fixture), all three
acceptance criteria from the issue are covered through the real CLI
(`CliRunner` → `zfa tdd make` → real `dart test` subprocesses), all three
deliberate mutants were killed, and the one intentionally amended existing test
(A15) is strengthened toward the amended contract with the issue reference
inline. The gaps: the bug workflow has no `tdd/test-list.md` (ordering evidence
is session-recorded; the commit is atomic, so git history alone shows LIKELY),
the fix reuses the profile `single` command for the per-behavior check without
a dedicated fixture for a `startedProcess: false` launch failure (a defensive
clause with no pinning test — triaged as equivalent-safe, see mutation
section), and 11 pre-existing failures elsewhere in the suite pre-date this
branch and are documented, not fixed, here.

## Test-first evidence

| Behavior                                                                                     | Class  | Evidence                                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 — a terminal-build failure against a pre-existing red suite takes the skip transition when the behavior's own test passes | PROVEN | RED captured verbatim (pre-fix run, this session): `baseline exit: 1, failed: 2` → `generation step failed at index 1 (build generated code for behavior U3)` → `outcome=generation-error`, exit 1; e2e CLI repro identical. GREEN post-fix: `outcome=skipped`, exit 0, green evidence appended, plan executed end to end (func + build invocations both logged). |
| B2 — a red target test after the failed terminal build keeps the honest generation-error       | PROVEN | Written green against pre-fix code (asserts the pre-existing honest stop), verified killed-mutant M2: tolerating a red target flips it to failure — the test owns the safe-failure contract.                                                                                                              |
| B3 — a failed non-terminal (scaffold) step keeps the honest generation-error                   | PROVEN | Written green against pre-fix code; the tolerance only engages for the terminal `build` step, so the func-step-failure test pins the fix's scope.                                                                                                                                                          |
| B4 — the composition plan's terminal build failure takes the same per-behavior skip transition (A15, amended) | PROVEN | RED captured verbatim (pre-fix run): A15 passed on pristine master asserting `generation-error`; post-fix the amended A15 asserts `outcome=skipped` + green entry + the `issue #737` marker in output, and fails under mutants M1/M3.                                                                      |

No assertion was weakened. `git diff` on the test file shows the 3 new tests
and the A15 amendment (contract `generation-error` → per-behavior `skipped`,
documented with the issue reference in the test name and body, following the
#694 amendment precedent). No test was renamed out of a filter's reach, skipped,
or excluded; no coverage/mutation gate was touched.

## Findings

| #   | Severity | Finding                                                                                                                                                                                                                       | Evidence                                                                             |
| --- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 1   | LOW      | The per-behavior check's `startedProcess: false` branch (launch failure → refuse tolerance) has no pinning fixture — mutant-equivalent in practice because `runSingle` is the same proven runner the drift check and step 8 use, but unmeasured by a dedicated test | `lib/src/plugins/tdd/commands/make_command.dart` (`_toleratedTerminalBuildFailure`) |
| 2   | LOW      | The workflow stated `.specify/bugs/<slug>/{issue,assessment}.md` were already committed; they exist on no branch. Records were reconstructed in this PR from GitHub issue #737 (the sole triage input) and this session's root-cause work | `.specify/bugs/tdd-make-plan-build-false-negative/assessment.md` header               |
| 3   | LOW      | Pre-existing failures pre-date this branch and are intentionally not remediated here (single-purpose PR): bug 657 verb-naming + spec 052 SC-004 in `make_command_test.dart`; scenario load/timeout flakes (sc_001/002/006/008/011 — identical failing files on pristine master, kernel-cache exhaustion on a ~10 GB disk); bug #691 run-state skip in `run_command_test.dart:395` | Pristine-tree stash runs: `make_command_test` fails the same 2; `scenarios` fails the same files (36−9); `run_command_test` fails the same 1 (28−1) |
| 4   | LOW      | The amended A15 changes a spec-052-pinned contract (US4: "a failed build likewise") without amending the spec text — the amendment lives in the test + bug records, mirroring the #731 precedent (behavior fix, spec text untouched) | `test/plugins/tdd/make_command_test.dart` A15 (amended); `specs/052-acceptance-make-composition/spec.md:184` |

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the tolerance logic the fix added in `make_command.dart` only
(`_toleratedTerminalBuildFailure` + the tolerated-path outcome). One mutant at
a time; every mutant was restored exactly (`git diff` shows no `MUTANT` markers,
analyze clean, format clean) and the bug-737 group re-run green (`+4`) after
each restore.

| Mutant                                                                              | Behavior  | Survived | Judgment                                                                                          |
| ----------------------------------------------------------------------------------- | --------- | -------- | ------------------------------------------------------------------------------------------------- |
| M1 — tolerance disabled (`return null` at guard entry)                                | B1, B4    | No       | `+2 −2`: the skip-transition test and amended A15 both fail with `outcome=generation-error` — the tests own the #737 false negative |
| M2 — target check dropped (tolerate regardless of the behavior's own test result)     | B2        | No       | `+3 −1`: killed by exactly the safe-failure test — the guard never masks a genuinely failed generation |
| M3 — tolerated path keeps `outcome=green` (skip-transition outcome dropped)           | B1, B4    | No       | `+2 −2`: both skip-transition tests fail on the `outcome=skipped` assertion — the #694 transition is pinned |

## Traceability (issue #737 Expected/Verification → tests)

| Criterion (issue #737)                                                                                  | Test(s)                                                              | Entry point |
| ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ----------- |
| A unit behavior's make should be checked per-behavior (e.g. `dart test test/tdd/u3_test.dart`), not full-suite | B1, B3 (new); the guard reuses the profile `single` command — the same per-behavior check the TDD loop is built on | real CLI    |
| If the current behavior's test passes after func scaffold, return `outcome=skipped` (per #694) and continue  | B1 (new), B4 (A15 amended)                                            | real CLI    |
| Run past U2 — U3:make `outcome=skipped`, run continues; full suite → NO NEW failures                          | B1 (pre-existing red sibling U4 red at baseline AND guard, tolerated; no NEW failures); the run-driver contract (`green`/`skipped` both success) pinned by `step_runner_test` +78 | real CLI    |

All tests claiming these criteria exist and run (session runs below); they
drive the real `zfa` CLI surface against real `dart test` subprocesses in temp
fixture projects, not unit doubles.

## Suite evidence (real runs, this session)

- `dart test --preset=all test/plugins/tdd/make_command_test.dart --name "737"` → RED `+0 −1` pre-fix (skip-transition test; controls already green); GREEN `+4` post-fix (3 new + amended A15).
- End-to-end CLI repro (minimal U1-U4 fixture, real `bin/zfa.dart`): pre-fix `generation step failed at index 1 … outcome=generation-error` exit 1; post-fix `per-behavior check: the behavior's own test passes … taking the #694 skip transition` → `outcome=skipped` exit 0, green evidence appended.
- `dart test --preset=all test/plugins/tdd/make_command_test.dart` → `+28 −2` (the 2 failures pre-date the branch, pristine-identical via stash run).
- `dart test --preset=all test/plugins/tdd/scenarios` → `+38 −8` (pristine master: `+36 −9`, same failing files — environmental load/kernel flakes, none fix-related).
- Consumers: `run_command_test` + `step_runner_test` + `runner_suite_test` + `compose_command_test` → `+78 −1` (pristine-identical failure at `run_command_test.dart:395`, bug #691).
- `tools/run_tests_chunked.sh` (fast tier, chunked with kernel cleanup, 66 chunks) → all runnable chunks passed; `test/plugins/tdd/scenarios` and `test/property` are slow-tier-only ("No tests ran" under the fast-tier selector — environmental, not failures).
- `dart analyze` → No issues found (full repo and the changed file).
- `dart format .` → changed files stable (`--set-exit-if-changed` exit 0); the only repo-wide format drift (`examples/mcp_demo/lib/src/mcp/tools.dart`) pre-exists on master and is excluded from this PR.

## What was not audited

- No mutation tool ran; the deliberate-mutant sample covered only the new
  tolerance logic (guard entry, target-check clause, outcome flip), not the
  untouched planner/pipeline/runner code paths.
- The `startedProcess: false` tolerance-refusal clause is unmeasured (finding 1).
- Coverage was not run (corroboration only per the rubric).
- The `integration`, `property`, and `benchmark` slow tiers were not run
  (temp-project + `build_runner` tiers; `dart_test.yaml` marks them unsafe on
  small/disposable agents — this session's disk is 9.9 GB).
- The scenario-suite failures were triaged as pre-existing/environmental by
  identical pristine-tree runs, not root-caused individually.
- The run driver's phase-1/phase-2 deferral interplay with the new
  `outcome=skipped` was verified only through `step_runner_test`'s outcome
  contract and the A15/B1 fixtures, not through a full `zfa tdd run` e2e
  scenario in this session.
