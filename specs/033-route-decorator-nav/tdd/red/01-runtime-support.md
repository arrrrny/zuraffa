# Red Evidence — Runtime support (params + guards)

**Test files**: `test/routing/route_params_test.dart`,
`test/routing/route_guard_test.dart`
**Behaviors**: B01 — typed param parsing; B02 — params holder; B03 — guard
contract + navigation context
**Spec**: FR-003, FR-004, FR-008, US-2, US-5, US-7

## First-run output (before implementation)

```
$ dart test test/routing/route_params_test.dart
  test/routing/route_params_test.dart:2:8: Error: Error when reading
  'lib/src/routing/route_params.dart': No such file or directory
  test/routing/route_params_test.dart:86:27: Error: Type 'ZfaRouteParams' not found.
00:00 +0 -1: Some tests failed.

$ dart test test/routing/route_guard_test.dart
  test/routing/route_guard_test.dart:2:8: Error: Error when reading
  'lib/src/routing/route_guard.dart': No such file or directory
  test/routing/route_guard_test.dart:80:27: Error: Type 'ZuraffaRouteGuard'
  not found.
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — neither library existed.
