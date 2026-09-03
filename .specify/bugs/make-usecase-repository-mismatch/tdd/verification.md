---
feature: make-usecase-repository-mismatch (bug #921)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 31b3ad62 # baseline audited; the fix lands as this PR's commit on top
behaviors: 3
proven: 1
likely: 0
test_after: 0
no_test: 0
na: 2 # characterization baselines, green by definition against untouched code
high_smells: 0
med_smells: 0
low_smells: 1
criteria_total: 2
criteria_covered: 2
mutants_applied: 2
mutants_killed: 2
mutants_survived: 0
suite: 68/68 chunked fast-tier folders OK; analyze parity 47/47 vs baseline; format clean
audit_mode: fallback # repo root is the CLI package itself; no .zfa.json, so /speckit.tdd.verify took its documented non-zuraffa LLM-guided path
---

# TDD Verification: zfa make Task usecase/repository mismatch (bug #921)

**Verdict: PASS_WITH_GAPS.** The defect is reproduced at both the product
level (exact compile error and exit code from the issue) and the unit level
(the new regression test fails against unmodified source), the conservative
fix makes the previously-red sequence end in `zfa build` exit 0 with "No
issues found", both targeted mutants are killed by the new suite, and the
full chunked fast suite is green with zero new failures. The verdict is not
`PASS` because the audit was not independent (the same session wrote the fix
and the tests and graded them), and because two of the three test-list
behaviors are characterization baselines that could not fail against the
baseline code — only the filtering behavior carries genuine red-driven
strength. Those gaps are structural to a one-session bug fix, are disclosed
rather than hidden, and do not weaken the product-level evidence.

## Behaviors and test-first evidence

Test list (3 behaviors) and their evidence classes. All red commands and
outputs are recorded verbatim in `tdd/cycle-log.md` (R-1, R-2); the fix and
its tests land in one commit, which per the rubric is `PROVEN` only because
the cycle log holds the red.

| Behavior (bug #921 acceptance)                                                    | Class            | Evidence                                                                                  |
| --------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------------------------- |
| 1. Use case for a method missing from the existing repository is not generated    | PROVEN           | R-1 product red (analyze exit 3, `undefined_method` at toggle_task_usecase.dart:20:24); R-2 unit red; G-1 green; mutant 1 killed |
| 2. Use cases for methods that exist on the interface are still generated          | NOT_APPLICABLE   | Characterization baseline — green against baseline and fix by construction; pins the guard against over-filtering (mutant 2 killed) |
| 3. Missing interface file fails open (unchanged behavior for same-plan generation)| NOT_APPLICABLE   | Characterization baseline — green against baseline and fix by construction; pins fail-open (mutant 2 killed) |

Existing tests were not weakened: the only changed test file gained a group
(3 tests, 147 added lines); the two pre-existing tests are byte-identical
(verified by reading the diff against 31b3ad62 — additions only, no
assertion removed, loosened, skipped, or renamed).

## Test smell audit

Read as written per the rubric, `test/plugins/usecase/entity_usecase_generator_test.dart`
against its own file's exemplars:

- 0 HIGH: every test asserts on the real generator output (artifact paths
  produced by `UseCasePlugin.generate` against a real temp filesystem); no
  doubles, no tautologies, no conditional logic, nothing skipped.
- 0 MED: no mystery guests (fixtures are created in-test per `setUp`/`tearDown`
  convention), deterministic (system temp dirs, no clocks/sleeps/network),
  failure output states the behavior via `reason:` on every assertion.
- 1 LOW (`Duplicated setup`): the `UseCasePlugin` construction is repeated
  across tests. This matches the file's existing two tests, which construct
  the plugin inline; flagged for awareness, not remediation — changing it
  would diverge from the file's established style.

## Test strength: deliberate mutants

No mutation tool is wired for this repo outside `zfa tdd verify`, so per the
rubric the two highest-risk behaviors were sampled with targeted mutants on
the changed file (`source_interface_guard.dart`), one at a time:

| Mutant (change to the fix)                                  | Expected                    | Result                                        |
| ----------------------------------------------------------- | --------------------------- | --------------------------------------------- |
| M1: filtering dropped (method set returned unchanged)        | skip-behavior test fails    | KILLED — `+4 -1: Some tests failed.`          |
| M2: fail-closed (returns `[]` when the interface exists)     | positive + fail-open fail   | KILLED — `+3 -2: Some tests failed.`          |

Both restorations verified byte-identical (`diff -q`), suite re-run green
(`+5: All tests passed!`). Sample size: 2 of 3 behaviors (the third has no
implementation branch of its own to mutate — it is the absence of
filtering). This is a sample, not an exhaustive run; the numbers say so.

## Traceability: issue acceptance criteria to evidence

From issue #921's Verification section. The issue offers three alternative
remediations; the brief for this fix selected option 1 (conservative), so
criterion 2 is satisfied by choice of remediation, not by test.

| # | Criterion (as filed)                                                                                | Evidence                                                                                              |
| - | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 1 | "A `zfa make Task` run produces only use cases that compile against the existing TaskRepository"     | Unit: guard tests 1–2. Product: R-1 red → G-1 green on the same sequence; sandbox `dart analyze` 0 errors |
| 2 | OR repository extended with missing methods (extension option) / `--usecases` flag (option 3)        | Not implemented by design (conservative option chosen per the fix brief); noted, not claimed             |
| 3 | "A test run after `zfa make Task` exits 0 from the build step"                                       | `zfa build` exit 0, "No issues found!" on the previously-red sequence (G-1)                              |

## Suite and gates

- `dart analyze` (repo root): 47 issues before the change (baseline 31b3ad62),
  47 after — parity; zero new findings; all 22 baseline errors are
  pre-existing `examples/todo_tdd` generated-file gaps unrelated to this fix.
- Chunked fast suite (`tools/run_tests_chunked.sh` semantics, run in batches
  over the identical chunk list): 68/68 folders OK, 0 failures, only
  `SKIP: no fast-tier tests` for slow-tier-only folders (core/dependencies,
  integration, property) — which the runner classifies as skips, not
  failures.
- `dart format .`: idempotent; `git diff --stat` shows only the fix (+15) and
  its tests (+147); no formatting-only diffs anywhere in the tree.

## Remediation (none required for the gate; noted for maintainers)

1. The audit was not independent (same-session author and auditor). A later
   cold-context re-audit of the guard tests against the rubric would close
   the independence gap.
2. During verification, two defects outside #921's scope were observed and
   deliberately not fixed here to keep this a one-bug PR:
   `zfa make <Entity> --service <bool-form> --methods=...` throws
   `type 'List<String>' is not a subtype of type 'String?'` (reproduced on
   baseline 31b3ad62), and with `--service=TaskService` the service plugin
   writes `domain/services/task_service.dart` while the usecase generator
   imports `domain/services/task/task_service.dart` and the generated
   interface body is empty. Both deserve their own triaged records.
