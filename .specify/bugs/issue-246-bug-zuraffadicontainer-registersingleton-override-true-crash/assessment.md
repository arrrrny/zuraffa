# Bug Assessment: bug: ZuraffaDIContainer.registerSingleton(override: true) crashes with null-check on get

- **Slug**: issue-246-bug-zuraffadicontainer-registersingleton-override-true-crash
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/246
- **Verdict**: already fixed on master (verified — reproduction test passes)
- **Severity**: critical (per labels), not reproducible on current origin/master

## Report (verbatim or summarized)

`ZuraffaDIContainer.registerSingleton(..., override: true)` crashed with a
null-check on the next `get<T>()` (`_ObjectRegistration.getObject` at
`get_it_impl.dart:257`). Reported on `development` @ `c25894f` (PR #242).

## Symptom

Null-check inside get_it's `_ObjectRegistration.getObject` when resolving a
type that was (re-)registered via `registerSingleton` with `override: true`.

## Reproduction

`flutter test test/core/module/di_container_override_test.dart` — the
`override parameter registerSingleton replaces with override: true` case.

## Suspected Code Paths

- `lib/src/core/module/di_container.dart` — `registerSingleton<T>` override
  branch. The original code used
  `getIt.registerSingletonWithDependencies<T>(...)`, which left stale internal
  state after an `unregister<T>` + re-register cycle, so the subsequent
  `get<T>()` resolved to a null registration.
- `ZuraffaDIContainer.get<T>` → `getIt.get<T>()`.

## Root Cause Hypothesis

`registerSingletonWithDependencies` defers object materialisation; combined
with an explicit `unregister`+re-register it produced a dangling
`_ObjectRegistration`. The fix eagerly materialises the instance and registers
the concrete object: `final instance = factoryFunc(); getIt.registerSingleton<T>(instance, ...)`.

## Proposed Remediation

Already applied on master. No further `lib/src` change required.

## Files likely to change

- `lib/src/core/module/di_container.dart` (already fixed)

## Tests to add

- `test/core/module/di_container_override_test.dart` already covers
  `registerSingleton`/`registerLazySingleton`/`registerFactory`/`registerInstance`
  override paths and passes on `origin/master` (`c0b3758`): `+13: All tests passed!`.

## Risks & Considerations

- None for the fix; it is present and verified.
- GitHub issue #246 is still OPEN although the fix is merged.

## Open Questions

- None. Not reproducible on current master.
