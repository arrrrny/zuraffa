# Bug Verification: `make --with=view` produces no view file in the xray default test

- **Slug**: make-xray-default-view-generation
- **Tested**: 2026-08-23
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix makes the xray-default test's temp project a Flutter project (added
`flutter:` to its pubspec). The view plugin now generates the `*_view.dart` file,
and the three xray-resolution subtests all pass. The original symptom no longer
reproduces and no regressions were observed in the changed area.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/commands/make_command_xray_default_test.dart` | pass | 3/3 subtests pass; views are now generated |
| New / updated tests | `dart test test/commands/make_command_xray_default_test.dart` | pass | same command; confirms the updated pubspec |
| Regression suite | `dart analyze test/commands/make_command_xray_default_test.dart` | pass | file analyzes cleanly (test-only change) |
| Lint / type-check | `dart analyze lib/src/plugins/view/view_plugin.dart` | skipped | unchanged source; flavor guard untouched |

## Output Excerpts

```
00:00 +0: (setUpAll)
00:23 +1: explicit xray:false in --from-json is preserved over the config default
00:45 +2: absent xray key falls back to .zfa.json xrayByDefault:true
01:09 +3: --xray CLI flag wins over xrayByDefault:false
01:09 +3: All tests passed!
```

## Residual Risks

- The fix is test-only and changes no production behavior. Pure-Dart consumers still
  get the Engine-Purity skip as intended; this only affects the in-test temp project.

## Recommendation

Close the bug — verified end-to-end. Merge `fix/make-xray-default-view-generation`.
