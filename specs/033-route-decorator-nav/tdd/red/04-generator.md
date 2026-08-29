# Red Evidence — Route config generator

**Test file**: `test/routing/route_config_generator_test.dart`
**Behaviors**: B13 — GoRoute/RouteParams source shape; B14 — ShellRoute
nesting; B15 — redirect + guard rendering; B16 — deep-link files
**Spec**: FR-002, FR-003, FR-005, FR-007, FR-008, US-1/3/4/5/6/7

## First-run output (before implementation)

```
$ dart test test/routing/route_config_generator_test.dart
  test/routing/route_config_generator_test.dart:3:8: Error: Error when
  reading 'lib/src/routing/route_annotation_scanner.dart': No such file or
  directory
  test/routing/route_config_generator_test.dart:4:8: Error: Error when
  reading 'lib/src/routing/route_config_generator.dart': No such file or
  directory
  test/routing/route_config_generator_test.dart:5:8: Error: Error when
  reading 'lib/src/routing/route_model.dart': No such file or directory
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — the only go_router emitter in the repo is the v5
entity RouteBuilder (annotation-driven generation did not exist).
