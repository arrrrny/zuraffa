---
feature: test-package-missing-after-setup
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 151271dd
behaviors: 5
proven: 3
likely: 1
test_after: 0
no_test: 0
not_applicable: 1
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # deliberate-mutant sampling only, no tool; n=1, caught
mutants_survived: 0
suite: >
  scoped audit suite 55 passed, 0 failed, 2s (patcher 11/11 + setup_command
  44/44, --preset=all); chunked fast suite tools/run_tests_chunked.sh: 64 of 66
  chunks green, 2 chunks carry 3 pre-existing environment-sensitive failures
  (-1 test/plugins/tdd/commands, -2 test/plugins/tdd/services) identical at
  base 029f6785 and passing in isolation — no new failures from this fix
---

# TDD Verification: test package missing from dev_dependencies after zfa setup (bug #716)

**Verdict: PASS_WITH_GAPS.** Discipline holds, every criterion is covered, the
deliberate mutant was caught, and no existing test was weakened — but mutation
is unmeasured beyond a single deliberate mutant (the profile wires no mutation
tool), one behavior's red was vacuously green (an idempotency guard that could
not fail pre-fix), and the acceptance evidence was captured on a disposable
scratch project with only its outputs committed. Audit run by the same session
that wrote the tests — not independent; every file was re-read from cold, and
the subagent option was unavailable, so the smell pass is self-audited.

## Test-first evidence

| Behavior | Class          | Evidence                                                                                                                             |
| -------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| A1       | PROVEN         | cycle 1 records the e2e red command + output (`evidence/red-e2e.md`: `Couldn't resolve the package 'test'`), committed in `fffd50ad` with the source change (per-cycle commit shape) |
| U1       | PROVEN         | cycle 1 red: `Expected: '^1.0.0' / Actual: <null>` (2 failed); test + fix in `fffd50ad` with the red in the log                      |
| U2       | PROVEN         | cycle 1 red: `Expected: true / Actual: <false>`; same commit shape                                                                   |
| U3       | LIKELY         | cycle 1 records the red run, but the does-not-duplicate test was vacuously green pre-fix (nothing to duplicate yet) — corroboration weak, finding 1 |
| U4       | NOT_APPLICABLE | characterization of the pre-existing dart-mode path (bug #688, untouched by this fix): green before and after, by definition         |

### Pre-existing tests touched by this change (the highest-signal check)

Two categories, both reviewed with before/after:

1. `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart:136` (now
   `dartDevDependencies includes test ^1.25.0`): the old assertion
   `expect(flutterDevDependencies.containsKey('test'), isFalse)` was REMOVED.
   Before: pinned the buggy contract. After: the opposite contract is pinned by
   new U1. This is a legitimate behavior change with its own list item (U1),
   not a weakening: the removed assertion's rationale — "Flutter projects use
   flutter_test (which re-exports test)" — is factually wrong (`flutter_test`
   wraps `test_api`/`matcher`, not the `test` runner package), and that wrong
   belief is the root cause of bug #716. The behavior change is the fix.
2. Counts `6` → `7` and `4` → `5` in `adds all seven missing
   dev_dependencies`, `does not duplicate existing entries`, and `creates
   dev_dependencies block when missing` (lines 29, 81, 115): mechanically
   updated cardinalities, plus a NEW `startsWith('test:')` assertion added at
   line 43 — strengthening, not loosening. No assertions were removed, no
   tolerances widened, no filters or tags changed, no skips added, and no
   thresholds lowered anywhere in the diff.

## Findings

Ordered by severity. No HIGH findings; the auditor fixes nothing.

| # | Severity | Finding                                                                                                                                                                      | Evidence                                                                    |
| - | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 1 | LOW      | U3's red is vacuous: an idempotency guard cannot fail against a bug that over-adds entries, so its test-first class is LIKELY, not PROVEN. Acceptable for a regression guard; do not manufacture a red. | `pubspec_dev_dependencies_patcher_test.dart:173`; cycle 1 note              |
| 2 | LOW      | A1's acceptance evidence was captured on a scratch project (`/home/z/my-project/repro716`) outside the repo; only the captured outputs are committed. Reproducing it requires the Flutter SDK and the reporter's `--platforms` flow. | `evidence/red-e2e.md`, `evidence/green-e2e.md`                              |
| 3 | LOW      | The chunked fast suite carries 3 pre-existing, environment-sensitive failures in `test/plugins/tdd/commands` (U-F2) and `test/plugins/tdd/services` (RefactorPasses U2, bug #689 PATH test) — identical counts at base `029f6785`, pass in isolation, PATH/cwd-contamination class already documented in `.specify/bugs/` (e.g. `cli-tests-cwd-contamination-in-integration-tests`, `test-harness-subprocess-deadlock`). NOT caused by this fix; recorded, not fixed (auditor rule 1). | `/tmp` chunked logs; base worktree re-runs; fix branch counts identical |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`); rubric
fallback: deliberate mutants on the behavior the acceptance criteria depend
on. Sample: 1 of 5 behaviors — the single map entry every criterion routes
through. Not exhaustive.

| Mutant                                                                        | Behavior | Survived | Judgment                                                                                          |
| ----------------------------------------------------------------------------- | -------- | -------- | ------------------------------------------------------------------------------------------------- |
| `flutterDevDependencies`: removed `'test': '^1.0.0'` (the bug re-introduced)  | U1, U2   | No       | Caught: +6 -5 (U1, U2, `adds all seven…`, `does not duplicate…`, `creates dev_dependencies block…`). Restored exactly via `git checkout`; re-run green 11/11; tree clean. |

## Traceability

| Criterion | Tests       | End to end |
| --------- | ----------- | ---------- |
| AC-1      | A1, U1, U2  | Yes — fresh `zfa setup` from source, generated pubspec inspected (`test: ^1.0.0` present) |
| AC-2      | A1, U2      | Yes — `flutter test test/tdd/a1_test.dart` compiles and runs to an honest-red assertion |
| AC-3      | U3          | Yes — unit at the real entry point (`ensure()`, the shared production path for both setup and tdd init) |
| AC-4      | U4          | Yes — dart-mode `ensure()` keeps `test ^1.25.0`, adds no `flutter_test` |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The slow tiers (`regression`, `integration`, `property`, `benchmark`) are
  excluded by `dart_test.yaml` by design and were not run; the chunked fast
  suite plus `--preset=all` on the two changed-file suites is the audited
  surface.
- `package_scaffold.dart`'s own dev_dependencies template (the `zfa package`
  surface) is out of the bug's scope and out of this audit.
- Coverage was not run (opt-in in the profile, not a gate).
- Deliberate-mutant sampling covered 1 of 5 behaviors; the un-sampled behaviors
  (U3, U4, A1's idempotency/paths) are unmeasured for strength, not proven
  strong.
- Performance and load: no criterion, no test, not assessed.
- The 3 pre-existing chunk failures were triaged (base-identical,
  isolation-pass) but not fixed — an audit does not fix.
