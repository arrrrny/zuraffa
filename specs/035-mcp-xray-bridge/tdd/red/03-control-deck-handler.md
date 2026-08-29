# Red Evidence — XRayControlDeckRequest / Response + Control Deck Handler

**Test file**: `test/mcp/xray_bridge/xray_control_deck_request_test.dart`
and the control-deck group of `xray_bridge_handlers_test.dart`
**Behaviors**: B04 (request parse), B11 (200 + injected payload), B12
(404 + availableMockNames), B13 (400 missing mockName), B16 (release 404)
**Spec**: FR-003, FR-008, FR-006

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_control_deck_request_test.dart

Failed to load "test/mcp/xray_bridge/xray_control_deck_request_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/mcp/xray_bridge/xray_control_deck_request.dart'.
  Error: Method not found: 'XRayControlDeckRequest', 'XRayControlDeckResponse'.
```

**Status**: RED ✓

## Resolution

Implementation: `lib/src/mcp/xray_bridge/xray_control_deck_request.dart`
(extends `XRayBridgeResponse` after the iteration noted in
`02-action-handler.md`).

Subsequent run (green): all control-deck tests pass.
