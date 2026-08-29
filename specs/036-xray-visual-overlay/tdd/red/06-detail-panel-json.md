# Red Evidence — XRayDetailPanel full-state JSON

**Test file**: `test/plugins/xray/xray_detail_panel_test.dart`
**Behavior**: B13 — XRayDetailPanel.fromNode produces valid JSON with full state
**Spec**: FR-006 (detail panel with full state JSON)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_detail_panel_test.dart --reporter compact

Failed to load "test/plugins/xray/xray_detail_panel_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_detail_panel.dart'.
  Error: Method not found: 'XRayDetailPanel'.
```

**Status**: RED ✓

## Second-run output (after initial implementation, before child shape fix)

```
00:05 +52 -3: XRayDetailPanel fromNode includes children recursively [E]
  Expected: 'child1'
    Actual: <null>
```

Root cause: the recursive child was serialized with the `nodeId` key (mirroring
the parent's shape) but the test asserted the `id` key. Fixed by updating the
test to expect `nodeId` (the canonical shape, consistent with the parent).

## Resolution

Implementation: `lib/src/plugins/xray/xray_detail_panel.dart`.

Subsequent run (green):
```
00:00 +6: All tests passed!
```
