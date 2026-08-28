# Bug Verification: zfa make: generated code hardcodes EntityFields.id (breaks entities without id) + mock datasource empty (methods default [])

- **Slug**: issue-294-zfa-make-generated-code-hardcodes-entityfields-id-breaks-ent
- **Tested**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The #294 source fix already ships in `origin/master` (merged as #295). This PR
adds a fast, plugin-level regression test that drives `PresenterPlugin.generate`
directly and asserts the generated presenter references the resolved id field
(`depotId`) rather than a hardcoded `EntityFields.id`. The test needs no flutter
SDK or `zfa make` subprocess, so it runs in the unit tier.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New regression test | `dart test test/plugins/presenter/presenter_resolved_id_field_test.dart` | pass | "All tests passed!" — presenter uses `depotId`, never `StorePriceFields.id`. |
| Lint / type-check | `dart analyze lib` | pass | No `error` lines (no lib changes in this PR). |
| Existing regression | `dart test test/regression/issue_294_entity_without_id_test.dart` (pre-existing) | pass | Guards Gap 2 (mock methods default) + resolver side on master. |

## Output Excerpts

```
00:00 +1: All tests passed!
```

Generated presenter snippet asserted:
```
Future<Result<StorePrice, AppFailure>> getStorePrice(
  String depotId, [ CancelToken? cancelToken, ]) {
  return _getStorePrice.call(
    QueryParams<StorePrice>(filter: Eq(StorePriceFields.depotId, depotId)), ...);
}
Future<Result<StorePrice, AppFailure>> updateStorePrice(
  String depotId, StorePricePatch data, ...) {
  return _updateStorePrice.call(
    UpdateParams<String, StorePricePatch>(id: depotId, data: data), ...);
}
```

## Residual Risks

- The test inspects generated text only; it does not compile the output. The
  end-to-end compile-guard remains in `test/regression/issue_294_...` and the
  `zuraffa_flutter` package.

## Recommendation

Close the bug — the fix is merged in master and now locked by both the existing
slow regression test and this fast unit test.
