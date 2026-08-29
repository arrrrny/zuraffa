# TDD Test List — MCP Server X-Ray Bridge

**Spec**: `specs/035-mcp-xray-bridge/spec.md`
**Plan**: `specs/035-mcp-xray-bridge/plan.md`
**Tasks**: `specs/035-mcp-xray-bridge/tasks.md`

## Behaviors

### B01 — XRayTreeResponse JSON round-trip

- **Spec**: FR-001 (`GET /xray/tree` returns activeView + nodes)
- **Test**: `test/mcp/xray_bridge/xray_tree_response_test.dart` — round-trip
- **Implementation**: `lib/src/mcp/xray_bridge/xray_tree_response.dart`

### B02 — XRayTreeResponse.empty

- **Spec**: FR-001 (no views mounted → empty tree, no error)
- **Test**: same file — `activeView: null`, `nodes: []`
- **Implementation**: same file — `XRayTreeResponse.empty` factory

### B03 — XRayActionRequest targetNode required + payload optional

- **Spec**: FR-002, FR-007
- **Test**: `test/mcp/xray_bridge/xray_action_request_test.dart`
- **Implementation**: `lib/src/mcp/xray_bridge/xray_action_request.dart`

### B04 — XRayControlDeckRequest mockName required

- **Spec**: FR-003, FR-008
- **Test**: `test/mcp/xray_bridge/xray_control_deck_request_test.dart`
- **Implementation**: `lib/src/mcp/xray_bridge/xray_control_deck_request.dart`

### B05 — handleTreeGet returns 200 with nodes

- **Spec**: FR-001, SC-001
- **Test**: `test/mcp/xray_bridge/xray_bridge_handlers_test.dart`
- **Implementation**: `lib/src/mcp/xray_bridge/xray_bridge_handlers.dart`

### B06 — handleTreeGet returns empty tree when no nodes

- **Spec**: FR-001
- **Test**: same file
- **Implementation**: same file

### B07 — handleActionPost returns 200 + invokes bound action

- **Spec**: FR-002, SC-002
- **Test**: same file
- **Implementation**: same file

### B08 — handleActionPost returns 404 + availableNodeIds for unknown target

- **Spec**: FR-007
- **Test**: same file
- **Implementation**: same file + `xray_bridge_error.dart`

### B09 — handleActionPost returns 400 when node has no bound action

- **Spec**: FR-002 (edge case)
- **Test**: same file
- **Implementation**: same file

### B10 — handleActionPost returns 400 when targetNode missing from body

- **Spec**: FR-002 (input validation)
- **Test**: same file
- **Implementation**: same file

### B11 — handleControlDeckPost returns 200 + injected payload

- **Spec**: FR-003
- **Test**: same file
- **Implementation**: same file

### B12 — handleControlDeckPost returns 404 + availableMockNames for unknown mock

- **Spec**: FR-008
- **Test**: same file
- **Implementation**: same file

### B13 — handleControlDeckPost returns 400 when mockName missing

- **Spec**: FR-003 (input validation)
- **Test**: same file
- **Implementation**: same file

### B14 — Release-mode handleTreeGet returns 404

- **Spec**: FR-006, SC-004
- **Test**: `test/regression/issue_184_xray_bridge_release_strip_test.dart` + same file
- **Implementation**: `XRayBridgeHandlers._isReleaseMode` guard

### B15 — Release-mode handleActionPost returns 404

- **Spec**: FR-006, SC-004
- **Test**: same regression file
- **Implementation**: same guard

### B16 — Release-mode handleControlDeckPost returns 404

- **Spec**: FR-006, SC-004
- **Test**: same regression file
- **Implementation**: same guard

### B17 — XRayBridgeAuth.isLocalhost

- **Spec**: FR-005 (localhost only in dev)
- **Test**: `test/mcp/xray_bridge/xray_bridge_auth_test.dart`
- **Implementation**: `lib/src/mcp/xray_bridge/xray_bridge_auth.dart`

### B18 — XRayBridgeAuth.validateBearerToken (constant-time)

- **Spec**: FR-005 (bearer token for remote)
- **Test**: same file
- **Implementation**: same file

### B19 — XRayDiff.add/remove/update round-trip

- **Spec**: FR-004 (tree diff payload)
- **Test**: `test/mcp/xray_bridge/xray_diff_test.dart`
- **Implementation**: `lib/src/mcp/xray_bridge/xray_diff.dart`

### B20 — XRayBridgeDiffStream broadcasts diffs

- **Spec**: FR-004
- **Test**: same file
- **Implementation**: same file — `XRayBridgeDiffStream` class

### B21 — Release-mode diff stream is empty + emit* are no-ops

- **Spec**: FR-006
- **Test**: same file + regression file
- **Implementation**: `XRayBridgeDiffStream._isReleaseMode` guard

### B22 — XrayCapability.triggerMock POSTs to /xray/control-deck

- **Spec**: FR-003 (URL contract compliance)
- **Test**: `test/mcp/capabilities/xray_capability_url_test.dart`
- **Implementation**: `lib/src/mcp/capabilities/xray_capability.dart` — URL fix

## Summary

- **Total behaviors**: 22
- **Total test files**: 7 (6 new + 1 modified existing)
- **Total implementation files**: 7 (6 new + 1 modified)
- **Spec FR coverage**: FR-001 (B01, B02, B05, B06), FR-002 (B03, B07, B08, B09, B10), FR-003 (B04, B11, B12, B13, B22), FR-004 (B19, B20, B21), FR-005 (B17, B18), FR-006 (B14, B15, B16, B21), FR-007 (B08), FR-008 (B12).
- **Spec SC coverage**: SC-001 (B05 — handler returns tree in <50ms), SC-002 (B07 — 100% accuracy via direct registry lookup), SC-003 (B05+B07 — full E2E within budget), SC-004 (B14, B15, B16, B21).

## TDD loop order

B01 → B22. Red evidence per behavior in `tdd/red/NN-*.md`. Final green state in `tdd/verification.md`.

## Verification gate

After all 22 behaviors are green:
- Run `dart analyze` — no new errors/warnings.
- Run `dart test` on the spec 035 scope — all pass.
- Record counts in `tdd/verification.md`.
