---
feature: 067-tdd-realize-mock-swap (bug #915 slice — differential harness)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: ba7b45c # short SHA audited (working tree carrying the #915 fix, pre-commit)
behaviors: 4 # reconstructed from the bug #915 remediation; the feature has no tdd/test-list.md
proven: 0
likely: 4
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 3/3 caught # deliberate-mutant sample (no mutation tool in the profile); scope: adapter_parity_checker.dart
mutants_survived: 0
suite: 2506 passed, 0 failed # fast tier via tools/run_tests_chunked.sh (67 chunks: 62 executed, 5 skipped — no fast-tier tests); focused parity file 23 passed, ~2s
---

# TDD Verification: Differential harness — fixture parity between mock and real adapters (bug #915)

> Post-audit note: master renumbered the spec directories mid-flight
> (892-… → 067-…, commit 5c0add5). This report and the fixture pair were
> audited under the pre-renumber `specs/892-tdd-realize-mock-swap/` paths;
> they now live at `specs/067-tdd-realize-mock-swap/`. Paths below reflect
> the current layout.

**Verdict: PASS_WITH_GAPS.** Every remediation criterion is covered by tests
through the real CLI entry point, no HIGH smells, and all three sampled
deliberate mutants were caught — but the ordering evidence is `LIKELY` rather
than `PROVEN` (the fix commit did not exist in history when this audit ran),
the mutation evidence is a sample, and the audit was written by the same
session that wrote the tests (not independent).

Audit target: the bug #915 change set only —
`lib/src/plugins/tdd/services/adapter_parity_checker.dart` (new),
`lib/src/plugins/tdd/commands/diff_check_command.dart` (new),
`lib/src/commands/tdd_command.dart` (registration),
`corpus_status_command.dart` / `corpus_audit_command.dart` (parity rollup
lines), `specs/067-tdd-realize-mock-swap/tdd/fixtures/rest-quotes/`
(committed fixture pair), `test/simulation/adapter_parity_checker_test.dart`
(new). The broader realize feature in `spec.md` was NOT the audit target.

## Test-first evidence

The feature has no `tdd/test-list.md`; the four behaviors below were
reconstructed from the bug #915 remediation (issue.md / assessment.md), which
is the authoritative contract for this slice.

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| 915-R1 fixture contract (`mock.json` + `real.json` per adapter contract, loaded for both lanes) | LIKELY | cycle-log Cycle 1 records the red (26 `Undefined name` compile errors, `00:00 +0 -1: Some tests failed.`); history cannot corroborate yet — the fix commit lands immediately after this audit, carrying test + implementation together (tdd-profile Conventions) |
| 915-R2 schema-parity checker (shape equality; drift = named verdict, exit 2) | LIKELY | same red/green evidence as R1 (same file, same cycle) |
| 915-R3 fault-injection parity (timeouts, 5xx, corrupted payloads on both lanes; `--full`) | LIKELY | same red/green evidence as R1 |
| 915-R4 corpus rollup (per-adapter parity score in corpus reports) | LIKELY | same red/green evidence as R1 |

No existing tests were touched by this change (no assertions removed,
loosened, skipped, or filtered out — verified by reading the diff; the only
pre-existing files modified are the two corpus commands and the tdd command
registry, none of which contain tests).

## Findings

| #   | Severity | Finding                                                                                                                                             | Evidence                                                              |
| --- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| 1   | LOW      | The named-verdict kind tokens (`field-drift`, `type-drift`, `fault-drift`) are not directly pinned; tests assert verdict, path, and both sides' shape names via substring. A rename of a kind token alone would not fail the suite | `test/simulation/adapter_parity_checker_test.dart:191-196,213-215`    |
| 2   | INFO     | `.specify/scripts/bash/check-prerequisites.sh --json --paths-only` with `SPECIFY_FEATURE_DIRECTORY` set resolves `FEATURE_DIR` without the `specs/` segment in this repo layout (`/home/z/zuraffa/067-tdd-realize-mock-swap` vs the real `/home/z/zuraffa/specs/067-tdd-realize-mock-swap`) | resolver run recorded in the audit session                            |
| 3   | PROCESS  | `tdd/test-list.md` absent for 892 — behaviors for this audit were reconstructed from the bug remediation; a future realize slice should plan through the extension so per-behavior evidence exists | `specs/067-tdd-realize-mock-swap/tdd/` has no test-list.md            |

## Mutation results

No mutation tool in the profile (tdd-profile.md); deliberate-mutant sampling
per the rubric. Sample: 3 mutants on `adapter_parity_checker.dart` — the file
every criterion depends on (the parity verdicts and exit classes are the
harness's money path). One small change each, run, restore exactly, re-run
green. Not exhaustive.

| Mutant                                                              | Behavior  | Survived | Judgment                                              |
| ------------------------------------------------------------------- | --------- | -------- | ----------------------------------------------------- |
| `exitCode` drift arm 2 -> 0                                          | 915-R2    | No       | Caught (1 failed: the drift exit-class test)           |
| `_compareFaults` early return (fault gate skipped)                   | 915-R3    | No       | Caught (2 failed: service-level + `--full` CLI tests)  |
| `_mergedElementShape` returns `empty` (element shapes never compared)| 915-R2    | No       | Caught (1 failed: list element shape drift test)       |

After each restore: suite re-run green (23 passed, 0 failed), analyzer clean,
zero mutant residue.

## Traceability

| Criterion (bug #915 remediation)                | Tests                                                                                  | End to end |
| ----------------------------------------------- | -------------------------------------------------------------------------------------- | ---------- |
| R1 fixture contract                              | fixture-contract group (3) + diff-check incomplete-exits-1 test                          | Yes        |
| R2 schema-parity checker                          | shape-parity group (7) + diff-check drift-exits-2 test                                   | Yes        |
| R3 fault-injection parity                         | fault-parity group (3) + diff-check --full test                                          | Yes        |
| R4 corpus rollup                                  | rollup group (3) + corpus-status / corpus-audit surface tests                            | Yes        |

Criteria with no test: none. Tests tracing to nothing: none.

The committed fixture pair
(`specs/067-tdd-realize-mock-swap/tdd/fixtures/rest-quotes/{mock,real}.json`)
was additionally exercised through the real binary:
`dart run bin/zfa.dart tdd diff-check --feature 067-tdd-realize-mock-swap --full`
-> `rest-quotes -> match`, `parity: ... score=1.00 result=match`, exit 0.

## What was not audited

- The broader realize feature (`specs/067-tdd-realize-mock-swap/spec.md`
  user stories, acceptance criteria, and functional requirements beyond the
  differential-gate slice): this audit graded bug #915's remediation only.
- Coverage: opt-in per the profile, not run — uncovered-branch signals are
  unmeasured.
- Mutation: 3 deliberate mutants on one file, not an exhaustive run; the
  command surface (`diff_check_command.dart`) and the corpus-command
  integration lines were exercised by tests but not mutated.
- The 5 skipped fast-tier chunks (benchmark, integration, property,
  tdd/scenarios, core/dependencies) contain no fast-tier tests; the slow
  tiers were not run on this small-disk cloud agent (per dart_test.yaml
  guidance).
- Performance of the parity check on large fixture sets: no criterion, no
  test, not assessed.

Remediation tasks: none appended (`--no-tasks` — the only findings are
LOW/INFO/PROCESS; none block, and the PR is scoped to bug #915 alone).
Finding 1 is the one worth picking up if the harness grows.
