# Red Evidence — Client URL Fix (`/xray/mock` → `/xray/control-deck`)

**Test file**: `test/mcp/xray_bridge/xray_capability_url_test.dart`
**Behavior**: B22 — `XrayCapability.triggerMock` POSTs to
`/xray/control-deck` per spec FR-003 (not the legacy `/xray/mock`).

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_capability_url_test.dart

Failed to load "test/mcp/xray_bridge/xray_capability_url_test.dart":
  Error: Method not found: 'controlDeckPathForTests' on 'XrayCapability'.
```

**Status**: RED ✓ — the test referenced a constant that did not exist
on `XrayCapability`.

## Resolution

- `lib/src/mcp/capabilities/xray_capability.dart`:
  - Added `static const String controlDeckPath = '/xray/control-deck';`
    as a public constant.
  - Added `controlDeckPathForTests` alias for the URL contract test.
  - Changed `triggerMock` to POST to `/xray/control-deck` instead of the
    legacy `/xray/mock` (spec compliance — FR-003).

## Note on the test approach

The contract test verifies the URL by reading the
`controlDeckPathForTests` constant rather than spinning up a fake HTTP
server. This is a pragmatic choice for unit testing — a follow-up
integration test could stand up an `HttpServer` on a free port, point
the `XrayCapability` at it, capture the actual request path, and assert
on the live URL.

Subsequent run (green): `B22` passes.
