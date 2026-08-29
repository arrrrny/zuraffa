# Red Evidence — Route validator (FR-006 / SC-003 / SC-004)

**Test file**: `test/routing/route_validator_test.dart`
**Behaviors**: B08 — duplicates; B09 — missing parent/cycle; B10 —
unsupported/unknown param types; B11 — redirect target; B12 — controller
type mismatch
**Spec**: FR-006, SC-003, SC-004

## First-run output (before implementation)

```
$ dart test test/routing/route_validator_test.dart
  test/routing/route_validator_test.dart:2:8: Error: Error when reading
  'lib/src/routing/route_annotation_scanner.dart': No such file or directory
  test/routing/route_validator_test.dart:3:8: Error: Error when reading
  'lib/src/routing/route_model.dart': No such file or directory
  test/routing/route_validator_test.dart:4:8: Error: Error when reading
  'lib/src/routing/route_validator.dart': No such file or directory
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no route validation engine existed.
