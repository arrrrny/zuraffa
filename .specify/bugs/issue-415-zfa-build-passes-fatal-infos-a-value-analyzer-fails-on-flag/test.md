# Bug Verification: zfa build: passes --fatal-infos a value → analyzer fails on flag → false 'no errors'

- **Slug**: issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag
- **Tested**: 2026-08-22T19:51:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix removes the rejected `--fatal-infos=false` flag from the post-build
analyzer invocation. The analyzer now runs and the guard correctly reports the
actual (warning/info-only) state of `lib` instead of a false "no errors". The
new regression test passes and the broader `dart analyze lib` shows no errors.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix behavior) | `dart analyze --fatal-infos=false lib` | fail (exit 64) | Confirms the original bug: flag rejected, empty stdout → false "no errors". |
| New / updated tests | `dart test test/commands/build_command_unit_test.dart --name "verifyAnalyzeOrFail"` | pass | "All tests passed!" — guard runs `dart analyze lib` and returns `true`. |
| Regression (whole lib) | `dart analyze lib` | pass (no errors) | 12 info/warning issues only; `analyzeReportsError` correctly returns `false`. |
| Lint / type-check | `dart analyze lib/src/commands/build_command.dart` | pass | No new errors introduced by the edit. |

## Output Excerpts

```
00:02 +1: All tests passed!
```

Post-fix analyzer run on lib:
```
12 issues found.
   ✅ dart analyze: no errors
```

## Residual Risks

- The regression test spawns a real `dart analyze` on the package root, so it is
  environment/CI dependent; it will also start failing if `lib` ever gains a
  genuine `error`-severity issue (which is the intended guard behavior).

## Recommendation

Close the bug — verified end-to-end. The fix is minimal and preserves the
existing error-detection contract.
