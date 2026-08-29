# Red Evidence — XRayOverlayState registry + subscription + release guard

**Test file**: `test/plugins/xray/xray_overlay_state_test.dart`
**Behaviors**: B01 (activate), B02 (deactivate), B03 (release no-op), B04
(register), B05 (unregister), B06 (changes stream), B14 (inspect)
**Spec**: FR-001, FR-007, FR-008, SC-001, SC-004

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_overlay_state_test.dart --reporter compact

Failed to load "test/plugins/xray/xray_overlay_state_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_overlay_state.dart'.
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_bounding_box.dart'.
  Error: Method not found: 'XRayOverlayState'.
  Error: Method not found: 'XRayBoundingBox'.
```

**Status**: RED ✓ — 11 test cases authored before
`lib/src/plugins/xray/xray_overlay_state.dart`,
`lib/src/plugins/xray/xray_bounding_box.dart`,
`lib/src/plugins/xray/xray_detail_panel.dart` existed.

## Resolution

Implementation files:
- `lib/src/plugins/xray/xray_overlay_state.dart`
- `lib/src/plugins/xray/xray_bounding_box.dart`
- `lib/src/plugins/xray/xray_detail_panel.dart`

Subsequent run (green):
```
00:02 +11: All tests passed!
```
