# Red Evidence — XRayActionRequest / Response + Action Handler

**Test file**: `test/mcp/xray_bridge/xray_action_request_test.dart` and
`test/mcp/xray_bridge/xray_bridge_handlers_test.dart`
**Behaviors**: B03 (request parse + payload optional), B07 (200 + action
invoked), B08 (404 + availableNodeIds), B09 (400 no bound action), B10
(400 missing targetNode), B15 (release 404)
**Spec**: FR-002, FR-007, FR-006

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_action_request_test.dart

Failed to load "test/mcp/xray_bridge/xray_action_request_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/mcp/xray_bridge/xray_action_request.dart'.
  Error: Method not found: 'XRayActionRequest', 'XRayActionResponse'.
```

## Compile-error iteration

Initial implementation of `XRayActionResponse` was a separate class
from `XRayBridgeResponse`, so `handleActionPost` failed to compile:

```
error - lib/src/mcp/xray_bridge/xray_bridge_handlers.dart:95:14 - A value of type
  'XRayActionResponse' can't be returned from the method 'handleActionPost'
  because it has a return type of 'XRayBridgeResponse'. - return_of_invalid_type
```

Fixed by making `XRayActionResponse` and `XRayControlDeckResponse` extend
`XRayBridgeResponse` (shared `statusCode` + `body` fields, `const`
constructor, factory subclasses).

## Resolution

- `lib/src/mcp/xray_bridge/xray_action_request.dart` — request + response.
- `lib/src/mcp/xray_bridge/xray_bridge_handlers.dart` — handler functions.

Subsequent run (green): all action-request tests + all handler tests pass.
