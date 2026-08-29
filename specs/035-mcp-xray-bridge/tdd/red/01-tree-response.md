# Red Evidence — XRayTreeResponse data class

**Test file**: `test/mcp/xray_bridge/xray_tree_response_test.dart`
**Behaviors**: B01 (JSON round-trip), B02 (empty factory)
**Spec**: FR-001 (`GET /xray/tree` returns activeView + nodes)

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_tree_response_test.dart

Failed to load "test/mcp/xray_bridge/xray_tree_response_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/mcp/xray_bridge/xray_tree_response.dart'.
  Error: Method not found: 'XRayTreeResponse'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/mcp/xray_bridge/xray_tree_response.dart`.

Subsequent run (green):
```
00:01 +7: All tests passed!
```
