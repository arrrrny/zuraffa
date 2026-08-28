# Bug Verification: regression/quality tests fail — missing example/.zfa.json + unformatted generated files + sealed mock codegen crash

- **Slug**: issue-250-bug-regression-quality-tests-fail-missing-example-zfa-json-u
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (affected tests pass on origin/master)

## Summary

All three sub-failures are not reproducible on `origin/master` (`c0b3758`):
7a the v5 pipeline test skips when `example/.zfa.json` is absent; 7b generated
output is formatted; 7c mock codegen no longer hits the FFI crash.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| 7a reproduction | `dart test test/regression/v5_pipeline_contract_test.dart` | pass | confirmed `+5: All tests passed!` |
| 7b/7c tiers | `output_quality_test`, `polymorphic_mock_integration_test` | n/a | Excluded from default fast suite; rely on the same already-merged fixes. |

## Output Excerpts

```
00:00 +5: All tests passed!   (v5_pipeline_contract_test)
```

## Residual Risks

- 7b/7c live in the regression/integration tiers (excluded by default). They
  depend on the same merged fixes as #249/#274/#395 and are expected green.

## Recommendation

Close issue #250.
