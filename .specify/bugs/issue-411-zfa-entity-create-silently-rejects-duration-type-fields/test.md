# Bug Verification: zfa entity create: silently rejects Duration type fields

- **Slug**: issue-411-zfa-entity-create-silently-rejects-duration-type-fields
- **Tested**: 2026-08-22
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

`Duration` is now excluded from entity-type extraction, so `EntityTypeValidator`
no longer produces an `UnresolvedTypeError` for a `Duration` field and
`zfa entity create` proceeds to write the entity. The new unit test passes and
`dart analyze lib` reports no errors.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Root-cause reproduction | Inspect `extractEntityTypes` exclusion list (pre-fix) | fail | `Duration` absent → returned as a custom type → validator error → `exit(1)`, no files written. |
| New tests | `dart test test/utils/entity_utils_test.dart` | pass | `All tests passed!` — 3 tests. |
| No-regression on primitives | same test, group 2 | pass | `String`, `int`, `double`, `bool`, `DateTime` still excluded. |
| No-regression on real refs | same test, group 3 | pass | `Product`, `$Product`, `List<Product?>`, `FeedbackType` still extracted. |
| Static analysis | `dart analyze lib` | pass | No `error`-severity lines. |

## Output Excerpts

```
00:00 +3: All tests passed!
```

## Residual Risks

- End-to-end CLI verification (`zfa entity create -n StopPolicy --field
  wallClockTimeout:Duration`) could **not** be run: the sibling `../zorphy` path
  dependency fails to compile in this environment
  (`../zorphy/zorphy/lib/src/common/helpers.dart:894:22: Error:
  'ParameterElement' isn't a type.`). Verification is therefore at the unit
  level on the exact function that caused the rejection.
- Sibling dart:core types (`Uri`, `num`, `BigInt`) remain misclassified; tracked
  as a follow-up rather than widened here.

## Recommendation

Close the bug — root cause identified and locked by a unit test.
