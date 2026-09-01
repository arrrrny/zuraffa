---
feature: tdd-runner-static-firstmatchvalue-compile-error (bugfix #695, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: ea399d96
behaviors: 1
proven: 1
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 100 # scope: changed declaration only, 1 deliberate mutant, caught
mutants_survived: 0
suite: 9 passed, 0 failed (runner_test.dart, slow tier) + 1 passed (regression guard, fast tier)
---

# TDD Verification: #695 runner.dart `_firstMatchValue` static/instance mismatch

**Verdict: PASS_WITH_GAPS.** The mismatch the issue flags is present in source at
`ea399d96` (declared `static`, invoked unqualified from six instance call sites);
the mandated Option B remediation is applied and pinned by a regression guard
whose RED was recorded before the fix and whose deliberate-mutant cycle was
executed for real. Gap: the exact compile error in the issue does not reproduce
under Dart 3.13.3 stable (same-class statics invoked by simple name are legal
Dart), so the original RED is source-level and historical, not a live compile
failure on this toolchain.

## Root cause (from issue, confirmed in source)

`lib/src/plugins/tdd/services/runner.dart`:

- Line 257 (at `ea399d96`): `static String? _firstMatchValue(String pattern, String input) { ... }`
- Lines 95, 120, 130, 173, 195, 203: six unqualified instance-style calls
  `_firstMatchValue(...)` inside `loadSingleTemplate` / `loadSuiteTemplate`.

Option B (preferred per the issue) applied: `static` removed, doc comment added
pinning the instance-method decision and citing the issue.

## Test-first evidence

| Behavior                                       | Class  | Evidence                                                                                                                                  |
| ---------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| U-695: `_firstMatchValue` is an instance method | PROVEN | `test/plugins/tdd/runner_instance_method_test.dart` added FIRST; run against `ea399d96` source → 1 failing test (RED recorded); fix commit turns it green |

RED command and output (before fix, on `ea399d96` + test):

```
dart test test/plugins/tdd/runner_instance_method_test.dart
00:00 +0 -1: Some tests failed.
Failing tests:
  test/plugins/tdd/runner_instance_method_test.dart:
    #695: _firstMatchValue is an instance method (no `static` keyword)
```

GREEN (after fix):

```
dart analyze lib/src/plugins/tdd/services/runner.dart   → No issues found!
dart test test/plugins/tdd/runner_instance_method_test.dart → +1: All tests passed!
dart test test/plugins/tdd/runner_test.dart --preset=all    → +9: All tests passed!
```

## Findings

| # | Severity | Finding                                                                                                                                                              | Evidence                                             |
| - | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1 | LOW      | The issue's compile-error RED is not reproducible on Dart 3.13.3: intra-class static-by-simple-name invocation is legal Dart, so `dart analyze` was already clean at baseline | baseline `dart analyze runner.dart` → No issues found |
| 2 | INFO     | The compiled binary in the issue's context (post-#657) was likely stale or built from a source state where the mismatch did break; not verifiable from this repo's history | git history contains no such state                    |

No `HIGH` smells in the new test: it asserts one specific declaration shape with
a named reason, reads the real source file, has no conditional logic, is
deterministic, and runs in the fast tier (< 1s).

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant                                                        | Behavior | Survived | Judgment                                                                                     |
| ------------------------------------------------------------- | -------- | -------- | -------------------------------------------------------------------------------------------- |
| re-introduce `static` on `_firstMatchValue` (the original bug) | U-695    | No       | Caught by the regression guard (RED run above); mutant restored, suite re-run green           |

Sample size: 1 of 1 changed behaviors — exhaustive for this single-declaration fix.

## Traceability (issue criteria → tests)

| Issue criterion                                                       | Test                                                                  | Real entry point?                                          |
| --------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------- |
| `dart analyze lib/src/plugins/tdd/services/runner.dart` → zero errors  | run in this audit (see GREEN)                                          | yes — the analyzer itself                                   |
| regression guard fails if `static` is re-introduced                     | `test/plugins/tdd/runner_instance_method_test.dart`                     | yes — source as compiled                                     |
| existing tests pass (no new failures)                                   | `runner_test.dart` 9/9 via `--preset=all` (slow tier, real subprocess) | yes — exercises `loadSingleTemplate`/`runSingle` end-to-end  |

## What was not audited

- `zfa tdd run <feature>` was not executed against a real generated project in
  this audit (the issue's A3 make-step scenario); the runner suite's real
  subprocess tests stand in for the template-loading path the bug touched.
- No mutation tool run (profile has none); a single deliberate mutant was used.
- The rest of the TDD plugin's 20+ services were not re-audited — out of scope
  for a single-declaration fix.
