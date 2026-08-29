# Red Evidence — XRayMockEntry data class + dedup equality + JSON round-trip

**Test file**: `test/plugins/xray/xray_mock_entry_test.dart`
**Behaviors**: B03 (dedup equality), B04 (JSON round-trip), B05 (empty payload)
**Spec**: FR-001 (entry shape), Edge case (dedup by name+payload, not name alone)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_mock_entry_test.dart

Failed to load "test/plugins/xray/xray_mock_entry_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_mock_entry.dart'.
  Error: Method not found: 'XRayMockEntry'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/plugins/xray/xray_mock_entry.dart` —
immutable data class with `name`/`payload`/`type` fields, `operator ==` /
`hashCode` by name+payload pair (per spec edge case), `toJson`/`fromJson`
round-trip.

Subsequent run (green):
```
00:02 +13: All tests passed!  (cumulative across xray_mock_type + xray_mock_entry)
```
