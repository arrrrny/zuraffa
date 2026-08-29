# Red Evidence — TypeMapper 037 extensions

**Test file**: `test/graphql/type_mapper_test.dart` (new `spec 037` group)
**Behaviors**: B25 — built-in scalars + DateTime + nullable + lists (FR-005);
B26 — scalarMap overrides + `.zfa.json` wiring + malformed entries (FR-006);
B27 — union/interface Dart representations (FR-008); plus `mapTypeRef`
**Spec**: FR-005, FR-006, FR-008, SC-003

## First-run output (before implementation)

```
$ dart test test/graphql/type_mapper_test.dart

  test/graphql/type_mapper_test.dart:122:33: Error: Member not found:
  'TypeMapper.fromZfaConfig'.
  test/graphql/type_mapper_test.dart:183:16: Error: The method 'mapTypeRef'
  isn't defined for the type 'TypeMapper'.
00:00 +0 -12: Some tests failed.

Failing tests (behavioral, beyond the compile errors):
  test/graphql/type_mapper_test.dart: DateTime maps to DateTime built-in
  (FR-005)   <- pre-change: DateTime fell through to the 'String' default
  test/graphql/type_mapper_test.dart: unionRepresentation produces a sealed
  Dart hierarchy (FR-008)
  test/graphql/type_mapper_test.dart: interfaceRepresentation produces an
  abstract class (FR-008)
  ...
```

**Status**: RED ✓ — 12 failures: `fromZfaConfig`, `mapTypeRef`,
`unionRepresentation`, `interfaceRepresentation` did not exist, and `DateTime`
mapped to `String?` (fall-through default) instead of `DateTime?`.
