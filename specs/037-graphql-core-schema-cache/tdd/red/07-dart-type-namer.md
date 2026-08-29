# Red Evidence — DartTypeNamer (naming conventions + reserved words)

**Test file**: `test/graphql/dart_type_namer_test.dart`
**Behaviors**: B23 — camelCase/PascalCase conventions; B24 — reserved-word
handling
**Spec**: FR-007

## First-run output (before implementation)

```
$ dart test test/graphql/dart_type_namer_test.dart

  test/graphql/dart_type_namer_test.dart:2:8: Error: Error when reading
  'lib/src/graphql/mapping/dart_type_namer.dart': No such file or directory
  test/graphql/dart_type_namer_test.dart:7:14: Error: Undefined name
  'DartTypeNamer'.
  ... (16 occurrences)
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no namer with reserved-word handling existed; the existing
`TypeMapper.fieldName`/`className` are pass-throughs that return reserved words
unchanged (e.g. `fieldName('class')` → `'class'`, invalid Dart).
