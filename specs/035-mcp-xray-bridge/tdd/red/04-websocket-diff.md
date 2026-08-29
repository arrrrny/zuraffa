# Red Evidence — XRayDiff + WebSocket Diff Stream

**Test file**: `test/mcp/xray_bridge/xray_diff_test.dart`
**Behaviors**: B19 (add/remove/update round-trip), B20 (broadcast),
B21 (release-mode empty)
**Spec**: FR-004 (WebSocket diff stream)

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_diff_test.dart

Failed to load "test/mcp/xray_bridge/xray_diff_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/mcp/xray_bridge/xray_diff.dart'.
  Error: Method not found: 'XRayDiff', 'XRayDiffType', 'XRayBridgeDiffStream'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/mcp/xray_bridge/xray_diff.dart` —
- `XRayDiffType` enum (add/remove/update).
- `XRayDiff` immutable class with three factories.
- `XRayBridgeDiffStream` class wrapping a
  `StreamController<XRayDiff>.broadcast()` with `emitAdd` / `emitRemove`
  / `emitUpdate` methods and a release-mode guard.

Subsequent run (green): all 9 diff tests pass.
