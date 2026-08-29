# Red Evidence — Compiler orchestration + zfa build wiring

**Test files**: `test/routing/route_annotation_compiler_test.dart`,
`test/commands/build_route_step_test.dart`
**Behaviors**: B17 — e2e + idempotency; B18 — 100 Views < 2s (SC-002);
B19 — empty/no-annotation; B20 — aggregated errors; B21 — build pre-step
**Spec**: FR-002, FR-006, SC-001, SC-002, SC-003, US-1/3/4

## First-run output (before implementation)

```
$ dart test test/routing/route_annotation_compiler_test.dart
  test/routing/route_annotation_compiler_test.dart:4:8: Error: Error when
  reading 'lib/src/routing/route_annotation_compiler.dart': No such file or
  directory
  test/routing/route_annotation_compiler_test.dart:39:29: Error: Method
  not found: 'RouteAnnotationCompiler'.
00:00 +0 -1: Some tests failed.

$ dart test test/commands/build_route_step_test.dart
  test/commands/build_route_step_test.dart:25:39: Error: Member not found:
  'BuildCommand.compileRouteAnnotations'.
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no compiler orchestration and no build-command hook.
