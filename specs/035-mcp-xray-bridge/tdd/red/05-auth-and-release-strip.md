# Red Evidence — XRayBridgeAuth + Release-mode Strip

**Test file**: `test/mcp/xray_bridge/xray_bridge_auth_test.dart` and
`test/regression/issue_184_xray_bridge_release_strip_test.dart`
**Behaviors**: B17 (isLocalhost), B18 (validateBearerToken constant-time),
B14/B15/B16 (release-mode 404 for all endpoints), B21 (release-mode
diff stream empty)
**Spec**: FR-005, FR-006, SC-004

## First-run output (before implementation)

```
$ dart test test/mcp/xray_bridge/xray_bridge_auth_test.dart

Failed to load "test/mcp/xray_bridge/xray_bridge_auth_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/mcp/xray_bridge/xray_bridge_auth.dart'.
  Error: Method not found: 'XRayBridgeAuth'.
```

```
$ dart test test/regression/issue_184_xray_bridge_release_strip_test.dart

Failed to load "test/regression/issue_184_xray_bridge_release_strip_test.dart":
  Error: Method not found: 'kXrayReleaseMode' (in lib/src/core/xray_config.dart).
  Error: Method not found: 'XRayBridgeHandlers'.
  Error: Method not found: 'XRayBridgeDiffStream'.
```

**Status**: RED ✓

## Iteration: unused local variable warning

The initial `_constantTimeEquals` implementation declared `var match = a.length == b.length`
in the length-mismatch branch but never read the final value (always returned `false`).
Analyzer flagged this as `unused_local_variable`. Fixed by removing the
unused `match` and replacing it with an explicit statement-without-result
loop that just consumes time (the loop's body has no side effects, but
satisfies the "constant-time" property by scanning the common prefix).

## Resolution

- `lib/src/mcp/xray_bridge/xray_bridge_auth.dart` — `isLocalhost` +
  `validateBearerToken` + `validateBearerTokenWithHeader`.
- `lib/src/mcp/xray_bridge/xray_bridge_handlers.dart` — `_isReleaseMode`
  guard on every handler.
- `lib/src/core/xray_config.dart` — added `kXrayReleaseMode` constant
  (also added by parallel spec 036 / 034 PRs — identical content; merges
  trivially).

Subsequent run (green): all auth + release-strip tests pass.
