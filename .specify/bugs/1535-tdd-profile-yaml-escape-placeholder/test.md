# Bug Verification: tdd-profile `single:` — YAML escapes + unknown placeholders

- **Slug**: 1535-tdd-profile-yaml-escape-placeholder
- **Tested**: 2026-09-16
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md

## Summary

The original symptom no longer reproduces: an honest red driven through a
double-quoted YAML `single:` template (escaped quotes) now runs exactly the
target test and classifies `RedClassification.assertion` (was `runner-error`,
exit 79), and an unknown placeholder spelling is rejected at load time with a
named remedy (was a silent broken template → `load-error`). No regressions
introduced by the change were found.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all` | pass | +9 incl. the slow AC-3 e2e (honest red → `assertion`, testCount == 1) |
| Reproduction (pre-fix control) | fix stashed → same command | fail (expected) | `+2 -7` — every bug behavior red; confirms the tests pin the bug, not the environment |
| New / updated tests | same file, fast tier | pass | +8 |
| Regression suite | `dart test test/plugins/tdd/services/` | pass* | +1120 −10; all 10 failures proven pre-existing (`refactor_passes_test.dart`, isolate `FormatException`) — identical with fix stashed |
| Runner-adjacent suites | `dart test test/plugins/tdd/runner_instance_method_test.dart test/plugins/tdd/verify_red_subdirectory_test.dart test/plugins/tdd/bug_830_widget_subject_kind_test.dart` | pass | +20 |
| Lint / type-check | `dart analyze <changed files>` | pass | No issues found! |
| Format gate | `dart format <changed files>` | pass | 0 changed |
| Mutation (targeted) | neutralize load-time rejection → rerun | mutant killed | exactly the 2 AC-2 behaviors fail; reverted, re-verified green |

## Output Excerpts

```
RED  (fix stashed):   00:02 +2 -7: Some tests failed.
  Expected: 'dart test {file} --plain-name "{name}"'
    Actual: 'dart test {file} --plain-name \\"{name}\\"'
GREEN (fix restored): 00:09 +9: All tests passed!
MUTANT (AC-2):        00:02 +6 -2: Some tests failed.
SERVICES regression:  01:16 +1120 -10  (10 pre-existing, env-specific)
ANALYZE:              No issues found!
FORMAT:               Formatted 2 files (0 changed)
```

## Residual Risks

- The end-to-end classification contract is exercised through the TddFixture
  honest-red project (real `dart test` subprocess, tagged `slow`), matching
  the issue's reproduction; a live `zfa tdd run` against a real feature was
  not performed on this machine because the compiled `zfa` binary is
  unavailable here (the loader → `runSingle` → `classify` path the issue
  exercises is covered end-to-end by the slow test).
- `refactor_passes_test.dart` carries a pre-existing, environment-specific
  isolate `FormatException` on this machine (unrelated to this fix; fails
  identically with the fix removed).

## Recommendation

Close the bug — the fix is verified against all four acceptance criteria with
red→green evidence re-proven in this session, a targeted mutation check, and
no change-induced regressions. Proceed to `/speckit-bug-pr slug=1535-tdd-profile-yaml-escape-placeholder`.
