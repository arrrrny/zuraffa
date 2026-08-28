# Bug Fix: Route shell constructor emits redundant explicit type on `navigationShell` param

- **Slug**: route-shell-named-constructor-377
- **Fixed**: 2026-08-23
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The `ShellRoutesBuilder` generated a `<Name>Shell` constructor whose `navigationShell` parameter was emitted as `required StatefulNavigationShell this.navigationShell` (explicit type + `this.`), and carried a leading `super.key` parameter. The #377 regression test requires the substring `MainShell({required this.navigationShell` (no `super.key` prefix), so it failed. The fix drops the redundant explicit `..type` and the `super.key` parameter so the constructor reads `MainShell({required this.navigationShell})`, matching the test and the builder's named `MainShell(navigationShell: navigationShell)` call.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/route/builders/shell_routes_builder.dart` | modified | Removed `..type = refer('StatefulNavigationShell')` from both `navigationShell` `Parameter` blocks (`_buildShellClass` and `_buildDesktopShellClass`). |
| `lib/src/plugins/route/builders/shell_routes_builder.dart` | modified | Removed the `key`/`super.key` `Parameter` (with `..toSuper = true`) from both shell constructors so `required this.navigationShell` is the first parameter after `{`. |

The `Field` declarations keep `..type = refer('StatefulNavigationShell')`, so the field type is unchanged and the parameter type is still inferred correctly.

## Diff Highlights

Before (bottom-nav constructor parameter):
```dart
Parameter(
  (p) => p
    ..name = 'navigationShell'
    ..type = refer('StatefulNavigationShell')   // removed
    ..named = true
    ..required = true
    ..toThis = true,
),
```
and the leading `..optionalParameters.add(Parameter((p) => p ..name = 'key' ..named = true ..toSuper = true))` block was removed.

Resulting generated output:
```dart
const MainShell({required this.navigationShell});
```

## Tests Added or Updated

- `test/regression/issue_377_route_shell_named_constructor_test.dart` — already covered both the bottom-nav and adaptive desktop shells; now passes.

## Local Verification

- `dart test test/regression/issue_377_route_shell_named_constructor_test.dart` → All tests passed! (2/2)
- `dart test test/plugins/route/ test/regression/route_generation_test.dart test/regression/issue_359_route_shell_test.dart test/dda/route_golden_test.dart` → All tests passed! (47/47)

## Deviations from Assessment

The assessment proposed only removing the redundant `..type`. On validation, the #377 test still failed because the `super.key` parameter appeared *before* `required this.navigationShell`, breaking the `MainShell({required this.navigationShell` substring match. The fix was extended to also remove the `key`/`super.key` parameter from both shell constructors. This matches the test's documented fixed form `MainShell({required this.navigationShell})` and the #377 contract (the shell route builder calls `MainShell(navigationShell: navigationShell)`).

## Follow-ups

- None.
