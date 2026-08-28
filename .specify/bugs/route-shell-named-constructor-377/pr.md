# Bug Fix PR: Route shell constructor emits redundant explicit type on `navigationShell` param

- **Slug**: route-shell-named-constructor-377
- **Opened**: 2026-08-23
- **PR**: 465
- **URL**: https://github.com/arrrrny/zuraffa/pull/465
- **Branch**: fix/route-shell-named-constructor-377
- **Issue**: n/a (no GitHub issue was filed; regression test `test/regression/issue_377_route_shell_named_constructor_test.dart` is the spec)

Fixes the generated `<Name>Shell` constructor so `navigationShell` is a named `this.` parameter (`MainShell({required this.navigationShell})`), resolving the #377 regression test. Dropped the redundant explicit `StatefulNavigationShell` type and the leading `super.key` parameter in `lib/src/plugins/route/builders/shell_routes_builder.dart`.
