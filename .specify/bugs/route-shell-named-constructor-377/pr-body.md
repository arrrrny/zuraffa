## Summary

The `ShellRoutesBuilder` generated a `<Name>Shell` constructor whose `navigationShell` parameter was emitted as `required StatefulNavigationShell this.navigationShell` (explicit type + `this.`) and carried a leading `super.key` parameter. This broke the #377 regression test, which requires the substring `MainShell({required this.navigationShell`.

The fix drops the redundant explicit `..type` and the `super.key` parameter so the constructor reads `MainShell({required this.navigationShell})`, matching the shell route builder's named `MainShell(navigationShell: navigationShell)` call. The `Field` declaration keeps the `StatefulNavigationShell` type, so the parameter type is still inferred correctly.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/route/builders/shell_routes_builder.dart` | modified | Removed `..type = refer('StatefulNavigationShell')` from both `navigationShell` `Parameter` blocks. |
| `lib/src/plugins/route/builders/shell_routes_builder.dart` | modified | Removed the `key`/`super.key` `Parameter` from both shell constructors. |

## Local Verification

- `dart test test/regression/issue_377_route_shell_named_constructor_test.dart` → All tests passed! (2/2)
- `dart test test/plugins/route/ test/regression/route_generation_test.dart test/regression/issue_359_route_shell_test.dart test/dda/route_golden_test.dart` → All tests passed! (47/47)
- `dart analyze lib/src/plugins/route/builders/shell_routes_builder.dart` → no errors (only pre-existing doc-comment info lints)

## Assessment

Assessment: `.specify/bugs/route-shell-named-constructor-377/assessment.md`
Fix: `.specify/bugs/route-shell-named-constructor-377/fix.md`
Verification: `.specify/bugs/route-shell-named-constructor-377/test.md`
