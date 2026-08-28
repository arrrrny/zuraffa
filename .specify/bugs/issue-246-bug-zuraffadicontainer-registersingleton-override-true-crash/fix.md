# Bug Fix: ZuraffaDIContainer.registerSingleton(override: true) crashes with null-check on get

- **Slug**: issue-246-bug-zuraffadicontainer-registersingleton-override-true-crash
- **Fixed**: 2026-08-22T19:50:00+00:00 (verified — fix already present on origin/master)
- **Assessment**: ./assessment.md
- **Status**: verified-fixed (no new `lib/src` change required)

## Summary

The reported crash (`_ObjectRegistration.getObject` null-check after
`registerSingleton(override: true)`) is **not reproducible on current
`origin/master` (`c0b3758`)**. The `registerSingleton` override path in
`lib/src/core/module/di_container.dart` already eagerly materialises the
instance and registers the concrete object
(`final instance = factoryFunc(); getIt.registerSingleton<T>(instance, ...)`)
instead of the previous `registerSingletonWithDependencies` approach that left
stale state after an `unregister`+re-register cycle.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/core/module/di_container.dart` | already fixed (no change made) | `registerSingleton` override path uses eager `registerSingleton<T>(instance)`. |

## Diff Highlights

No new diff — the fix is already merged. The relevant logic:

```dart
if (override && getIt.isRegistered<T>(instanceName: instanceName)) {
  await getIt.unregister<T>(instanceName: instanceName);
}
final instance = factoryFunc();
getIt.registerSingleton<T>(instance, instanceName: instanceName);
```

## Tests Added or Updated

- None required: `test/core/module/di_container_override_test.dart` already
  covers the `registerSingleton` override case and passes.

## Local Verification

- `dart test test/core/module/di_container_override_test.dart` →
  `00:00 +13: All tests passed!` (exit 0) on `origin/master` `c0b3758`.

## Deviations from Assessment

None — assessment concluded the fix is already applied.

## Follow-ups

- Close GitHub issue #246 (the fix is merged but the issue label is still open).
