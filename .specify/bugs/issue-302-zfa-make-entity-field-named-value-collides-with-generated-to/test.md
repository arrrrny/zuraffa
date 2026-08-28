# Bug Verification: zfa make: entity field named 'value' collides with generated toggle params → duplicate_definition in controller/presenter (Barcode)

- **Slug**: issue-302-zfa-make-entity-field-named-value-collides-with-generated-to
- **Tested**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The #302 source fix already ships in `origin/master` (merged as #305): the
toggle-value parameter is renamed to the reserved `toggleValue`. This PR adds a
fast, plugin-level regression test that drives the presenter and controller
plugins directly and asserts the generated toggle method uses `bool toggleValue`
and forwards it into `ToggleParams.value`, with no duplicate `bool value`
parameter — even when the entity's id field is the literal `value`. The test
needs no flutter SDK or `zfa make` subprocess, so it runs in the unit tier.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New regression test | `dart test test/plugins/toggle_value_param_test.dart` | pass | 3/3 tests — presenter + controller use `toggleValue`, no collision; canonical `id` control passes. |
| Lint / type-check | `dart analyze lib` | pass | No `error` lines (no lib changes in this PR). |
| Existing regression | `dart test test/regression/issue_302_toggle_param_collision_test.dart` (pre-existing) | pass | Guards resolver + loud-error path on master. |

## Output Excerpts

```
00:00 +3: All tests passed!
```

Generated presenter snippet asserted:
```
Future<Result<Barcode, AppFailure>> toggleBarcode(
  String value,
  Field<Barcode, dynamic> field,
  bool toggleValue, [ CancelToken? cancelToken, ]) {
  return _toggleBarcode.call(
    ToggleParams<String, Field<Barcode, dynamic>>(
      id: value, field: field, value: toggleValue), ...);
}
```

## Residual Risks

- The test inspects generated text only; it does not compile the output. The
  end-to-end compile-guard remains in `test/regression/issue_302_...` and the
  `zuraffa_flutter` package.

## Recommendation

Close the bug — the fix is merged in master and now locked by both the existing
slow regression test and this fast unit test.
