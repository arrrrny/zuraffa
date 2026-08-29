# Red Evidence — XRayBoxLabel format

**Test file**: `test/plugins/xray/xray_box_label_test.dart`
**Behavior**: B10 — XRayBoxLabel format produces canonical inline label
**Spec**: FR-003 (inline labels: nodeId, status, action, state)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_box_label_test.dart --reporter compact

Failed to load "test/plugins/xray/xray_box_label_test.dart":
  test/plugins/xray/xray_box_label_test.dart:7:8: Error: Target of URI doesn't exist.
    import 'package:zuraffa/src/plugins/xray/xray_box_label.dart';
            ^
  test/plugins/xray/xray_box_label_test.dart:12:18: Error: Method not found: 'XRayBoxLabel'.
        const label = XRayBoxLabel(
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/plugins/xray/xray_box_label.dart`.

Subsequent run (green):
```
00:00 +6: All tests passed!
```
