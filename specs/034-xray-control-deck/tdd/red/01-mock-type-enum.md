# Red Evidence — XRayMockType enum + color mapping

**Test file**: `test/plugins/xray/xray_mock_type_test.dart`
**Behaviors**: B01 (color palette), B02 (fromString case-insensitive + fallback)
**Spec**: FR-001 (optional type/color), FR-004 (color-coded buttons)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_mock_type_test.dart

Failed to load "test/plugins/xray/xray_mock_type_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_mock_type.dart'.
  Error: Method not found: 'XRayMockType'.
```

**Status**: RED ✓ — 9 test cases authored before
`lib/src/plugins/xray/xray_mock_type.dart` existed.

## Resolution

Implementation: `lib/src/plugins/xray/xray_mock_type.dart` —
enum with `color` field, `label` getter, and `fromString(String?)` static
(case-insensitive, fallback to `unknown`).

Subsequent run (green):
```
00:02 +9: All tests passed!
```
