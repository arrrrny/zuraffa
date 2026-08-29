# Red Evidence — SDL printer

**Test file**: `test/graphql/sdl_printer_test.dart`
**Behavior**: B01 — SDL printer renders object types, enums, unions, interfaces, roots
**Spec**: FR-001 (SDL artifact), Key Entities

## First-run output (before implementation)

```
$ dart test test/graphql/sdl_printer_test.dart

  test/graphql/sdl_printer_test.dart:4:8: Error: Error when reading
  'lib/src/graphql/sdl/sdl_printer.dart': No such file or directory
  test/graphql/sdl_printer_test.dart:23:27: Error: Method not found: 'SdlPrinter'.
  test/graphql/sdl_printer_test.dart:29:27: Error: Method not found: 'SdlPrinter'.
  ... (8 occurrences)
00:00 +0 -1: Some tests failed.

Failing tests:
  test/graphql/sdl_printer_test.dart: loading test/graphql/sdl_printer_test.dart
```

**Status**: RED ✓ — test authored before `lib/src/graphql/sdl/sdl_printer.dart`
existed. Compile-error red phase is acceptable per the constitution's
Test-First gate.
