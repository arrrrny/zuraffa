---
feature: tdd-make-uses-behavior-id-as-entity-name (bugfix #696, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 6f4d94e5
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # scope: changed branch, 1 deliberate mutant, caught, restored
mutants_survived: 0
suite: planner 14/14, real-CLI guard 2/2, make_command bug-696 pair 2/2 (suite-wide counts in the shared verify)
---

# TDD Verification: #696 `zfa tdd make` uses the behavior ID as an entity name

**Verdict: PASS_WITH_GAPS.** The CRUD/use-case branch no longer hands the
slugified behavior ID to the real CLI as a bare entity name: the name is
derived from the behavior's trace (explicit target, then a capitalized
entity name in the description), and only a description that names no
entity at all falls back to the slug — carrying `--no-entity`, whose
acceptance by the REAL CLI was proved in this audit. Gap: literal
FR-xxx→entity resolution from spec.md prose was NOT implemented (the
planner is pure by design; the description trace is what it can honestly
read).

## Root cause (from issue, confirmed in source)

`lib/src/plugins/tdd/services/generation_planner.dart` branch 2 (at
`6f4d94e5`): for a CRUD/use-case behavior, the make name was

```dart
final slug = summary.target ?? _slugify(summary.behaviorId) ?? 'feature_${summary.behaviorId}';
```

For a unit behavior like `U5` with no explicit target this slugified the
BEHAVIOR ID (`u5`) and emitted `zfa make u5`. The real `zfa make` (#496
fail-fast in `lib/src/commands/make_command.dart:478`) rejects any name
without an entity source file:

```
Cannot run `zfa make` for "u_6": no entity source file was found.
```

— the issue's exact failure, reproduced against the real CLI in this
audit's drift-guard test (bare-slug step).

## Remediation (issue: derive the entity name / use --no-entity)

- The name is derived from the behavior's trace: `summary.target`
  first, then `_extractEntityName(description)` (a capitalized name after
  "entity …" or "create …" — e.g. "create User use case …" → `User`).
- Only when the description names no entity does the plan fall back to
  the slugified id — and emits `['make', <slug>, '--no-entity']` so the
  real CLI's #496 fail-fast cannot break the run.
- The real-CLI drift guard proves BOTH sides: the bare slug is rejected
  with the issue's exact error, and the planner-emitted argv (same slug
  with `--no-entity`) exits 0 against the real `bin/zfa.dart`.

## Test-first evidence

| Behavior                                                             | Class  | Evidence                                                                                                                                                      |
| -------------------------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| U-696a: description-named entity → `make <Entity>` (not the id slug)  | PROVEN | planner unit test written FIRST; run on base → failed (`['make', 'u5']` recorded); fix commit turns it green. Slow fixture twin: fake-zfa log shows `make User` |
| U-696b: no derivable name → `make <slug> --no-entity`                 | PROVEN | planner unit test written FIRST; run on base → failed (no `--no-entity`); passes after fix. Slow fixture twin: `make u_6 --no-entity` run goes green end-to-end  |
| U-696c: explicit target wins, no flag                                 | PROVEN | planner unit test; passed pre-fix (guard pins precedence) and post-fix                                                                                          |

RED commands (before fix, recorded output):

```
dart test test/plugins/tdd/services/generation_planner_test.dart
Failing tests:
  … U-696a: … derives the `make` name from the description trace, not from the behavior ID
  … U-696b: … passes --no-entity so the real CLI does not fail-fast …

dart test test/plugins/tdd/services/generation_planner_real_cli_test.dart --preset=all
00:46 +1 -1: Some tests failed.   # the emitted argv lacked --no-entity
```

GREEN (after fix):

```
dart analyze lib/                                   → No issues found!
dart test test/plugins/tdd/services/generation_planner_test.dart          → +14 All tests passed!
dart test test/plugins/tdd/services/generation_planner_real_cli_test.dart
  --preset=all                                                            → +2 All tests passed!
dart test test/plugins/tdd/make_command_test.dart --preset=all \
  --plain-name "bug 696"                                                  → +2 All tests passed!
```

## Findings

| # | Severity | Finding                                                                                                                                                                                                 | Evidence                                            |
| - | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1 | LOW      | The literal issue option "derive the entity name from the behavior's trace (FR-xxx)" via spec.md prose parsing was not implemented — the planner is pure (no file IO, FR-006 audit trail), and mining FR prose for names would be speculative text coupling. The description trace (which carries the FR-named subject) is used instead | generation_planner.dart branch 2                    |
| 2 | LOW      | `--no-entity` runs produce scaffolds named after the slug (`u_6`) when no better name exists — functional, but follow-up naming hygiene (e.g. deriving from the feature name) could improve output quality | branch-2 fallback                                   |

No `HIGH` smells in the new tests: exact argv pins with named reasons, no
conditionals, deterministic, fixture helpers reused (no bypassed utilities),
real-CLI guard runs the actual `bin/zfa.dart` in a temp project.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                        | Behavior | Survived | Judgment                                                                                      |
| ------------------------------------------------------------- | -------- | -------- | ---------------------------------------------------------------------------------------------- |
| remove `--no-entity` from the fallback argv (`['make', slug]`) | U-696b   | No       | Caught by U-696b (exact argv pin); mutant restored, analyze clean, planner suite re-run green    |

Sample: the changed branch has one decision point (derived name vs slug) —
exhaustively sampled.

## Traceability (issue criteria → tests)

| Issue criterion                                                                    | Test                                             | Real entry point?                                      |
| ---------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------- |
| `zfa tdd make U5` must not run `zfa make u5` (bare)                                 | planner U-696a + fixture `make User` twin         | yes — in-process CLI + real `dart test` subprocesses     |
| unit behaviors with no entity name still generate (make succeeds)                   | planner U-696b + fixture `--no-entity` green twin | yes — full make run, exit 0, green evidence              |
| planner argv accepted by the REAL CLI                                               | real-CLI drift guard (bug #696 group)             | yes — spawns the real `bin/zfa.dart`                     |
| full suite → NO NEW failures (shared verify)                                        | deferred to the branch-level verify run           | — (shared verify section of the bug combo)               |

## What was not audited

- The FR-xxx prose→entity resolution path (not implemented; see finding 1).
- Generation OUTPUT quality for `--no-entity` scaffolds (files compile? — the
  fixture's fake pipeline stands in for generation; the real generation
  quality is the `zfa make` surface's own contract).
- The 2 pre-existing make_command failures documented in the #694 audit are
  equally out of scope here (planner-message owner).

## Shared verify (branch-level, combined stack 695→694→696)

- `dart analyze` (whole repo) → No issues found
- `tools/run_tests_chunked.sh` (fast suite, chunked) → SCRIPT_EXIT=0, 66 chunks, **2509 tests, 0 failures** (`OK: all chunks passed.`)
- `dart format .` (Dart 3.13.3) → 0 files changed after the `chore: dart format 3.13.3` commit; `git diff --stat` → empty (zero remaining formatting diffs)
- 2 failures in `make_command_test.dart` (planner-message wording) were verified PRE-EXISTING on the base commit via `git stash` and are out of scope; they are counted in the per-file runs above, not in the chunked fast suite (both are slow-tier tests)
