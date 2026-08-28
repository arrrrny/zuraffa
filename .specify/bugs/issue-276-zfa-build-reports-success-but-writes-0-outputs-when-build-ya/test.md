# Bug Verification: zfa build reports success but writes 0 outputs when build.yaml is missing

- **Slug**: issue-276-zfa-build-reports-success-but-writes-0-outputs-when-build-ya
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (build guard present on origin/master)

## Summary

The silent false-success (0 outputs reported as ✅) is not reproducible on
`origin/master` (`c0b3758`). `build_command.dart` fails loudly via
`ensureBuildYaml()` pre-flight and `verifyOutputsOrFail()` /
`verifyDeclaredPartsOrFail()` post-build.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction | `dart test test/commands/build_command_unit_test.dart` | pass | `+40: All tests passed!` |
| Guard coverage | `ensureBuildYaml` / `verifyOutputsOrFail` / `verifyDeclaredPartsOrFail` | pass | Tests cover the 0-output failure path. |

## Output Excerpts

```
00:21 +40: All tests passed!   (build_command_unit_test)
```

## Residual Risks

- Full `build.yaml` scaffolding bootstrap is tracked under #275; this issue's
  standalone robustness ask (fail loudly on 0 outputs) is satisfied.

## Recommendation

Close issue #276.
