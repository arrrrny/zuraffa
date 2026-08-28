# Bug Fix: issue-409 — provider overrides must keep the `NoParams` parameter

- **Slug**: issue-409-zfa-provider-service-methods-use-noparams-but-provider-gener
- **Issue**: https://github.com/arrrrny/zuraffa/issues/409
- **Outcome**: already fixed in-tree; verified by reproduction and covered by an added regression guard

## Verification (real CLI reproduction)

A throwaway project (`pubspec.yaml` with a path dependency on this repo) was used
to run the issue's reproduction verbatim:

```bash
dart run zuraffa:zfa service method --target MyService --name list \
  --params NoParams --returns "List<Item>"
dart run zuraffa:zfa provider create MyService --data --force
```

Generated `lib/src/data/providers/my_service/my_provider.dart`:

```dart
class MyProvider with Loggable, FailureHandler implements MyService {
  @override
  Future<List<Item>> list(NoParams params) async { ... }
}
```

The signature matches `MyService.list(NoParams params)`, so no `invalid_override`
occurs. The variant that goes through `method_append`
(`zfa provider method --target MyService --name list --params NoParams
--returns "List<Item>"`) was also run and emits matching service/provider
signatures.

## Why it is already fixed

`lib/src/plugins/provider/builders/provider_builder.dart:132-161` (the
`existingMethods` branch cited in the issue) unconditionally emits a
`params` parameter typed from `ParsedUseCaseInfo.paramsType`, and
`lib/src/utils/method_extractor.dart:53` defaults that type to `NoParams`
rather than leaving it empty. The source fix landed in PR #422; the
provider-create path is guarded by
`test/regression/issue_409_provider_noparams_override_guard_test.dart` and
`test/regression/issue_409_noparams_provider_override_test.dart` (both pass).

## Change made in this branch

The `method_append` half of the reproduction (`zfa provider method` /
`zfa service method` with `--params NoParams`, which creates both files through
`MethodAppendBuilder._createService` / `_createProvider`) had no `NoParams`
guard. Added:

- `test/regression/issue_409_provider_method_noparams_test.dart` — asserts the
  generated service and provider both declare
  `Future<List<Item>> list(NoParams params)` and that no zero-arg `list()`
  override is emitted.

No production code changes were needed.

## Validation

```bash
dart test --preset=regression \
  test/regression/issue_409_provider_method_noparams_test.dart \
  test/regression/issue_409_provider_noparams_override_guard_test.dart \
  test/regression/issue_409_noparams_provider_override_test.dart   # all pass
dart analyze test/regression/issue_409_provider_method_noparams_test.dart  # clean
dart analyze lib                                                          # unchanged
```
