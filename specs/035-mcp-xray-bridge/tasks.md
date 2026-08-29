# Tasks: MCP Server X-Ray Bridge — Tree Inspection & Action Execution

**Input**: Design documents from `specs/035-mcp-xray-bridge/`

**Prerequisites**: plan.md, spec.md.

**Tests**: Tasks marked `[T]` are behavior-driving test tasks written FIRST (TDD red).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T01 Create `lib/src/mcp/xray_bridge/` directory + `test/mcp/xray_bridge/` directory.

## Phase 2: Tree Response (User Story 1 — Inspect Live UI Tree, P1)

- [ ] T02 [T] US1 RED: Write `test/mcp/xray_bridge/xray_tree_response_test.dart`:
  - `XRayTreeResponse(activeView: 'ProfileView', nodes: [...]).toJson()` produces `{"activeView": ..., "nodes": [...]}`.
  - `XRayTreeResponse.empty` has `activeView: null` and `nodes: []`.
  - Round-trips through `fromJson`.
- [ ] T03 US1 GREEN: Implement `lib/src/mcp/xray_bridge/xray_tree_response.dart`. Passes T02.

## Phase 3: Action Request/Response (User Story 2 — Trigger Actions, P1)

- [ ] T04 [T] US2 RED: Write `test/mcp/xray_bridge/xray_action_request_test.dart`:
  - `XRayActionRequest(targetNode: 'n1')` has `payload: null`.
  - `XRayActionRequest(targetNode: 'n1', payload: {'k':'v'})` round-trips through `toJson`/`fromJson`.
  - Missing `targetNode` field throws.
- [ ] T05 US2 GREEN: Implement `lib/src/mcp/xray_bridge/xray_action_request.dart`. Passes T04.

## Phase 4: Control Deck Request/Response (User Story 3 — Trigger Mocks, P2)

- [ ] T06 [T] US3 RED: Write `test/mcp/xray_bridge/xray_control_deck_request_test.dart`:
  - `XRayControlDeckRequest(mockName: 'Expired Product')` round-trips.
  - Missing `mockName` throws.
- [ ] T07 US3 GREEN: Implement `lib/src/mcp/xray_bridge/xray_control_deck_request.dart`. Passes T06.

## Phase 5: Bridge Error Helper (FR-007, FR-008)

- [ ] T08 [T] US2 RED: Write `test/mcp/xray_bridge/xray_bridge_error_test.dart` (covered in the handlers test file):
  - `XRayBridgeError.notFoundForNode(['n1', 'n2'])` produces a 404 response with `availableNodeIds` field.
  - `XRayBridgeError.notFoundForMock(['Valid Product', 'Error'])` produces a 404 response with `availableMockNames` field.
  - `XRayBridgeError.noBoundAction(nodeId)` produces a 400 response.
- [ ] T09 US2 GREEN: Implement `lib/src/mcp/xray_bridge/xray_bridge_error.dart`. Passes T08.

## Phase 6: Handlers (User Stories 1, 2, 3)

- [ ] T10 [T] US1 RED: Write `test/mcp/xray_bridge/xray_bridge_handlers_test.dart`:
  - `handleTreeGet()` returns 200 with `activeView` and `nodes` when overlay has nodes.
  - `handleTreeGet()` returns 200 with `activeView: null` and `nodes: []` when overlay is empty.
  - `handleTreeGet()` returns 404 in release mode.
- [ ] T11 [T] US2 RED: extend the handlers test file:
  - `handleActionPost({targetNode: 'n1'})` returns 200 with success message when node exists + has bound action.
  - `handleActionPost({targetNode: 'unknown'})` returns 404 with `availableNodeIds` listing registered node ids.
  - `handleActionPost({targetNode: 'n1'})` returns 400 when node has no bound action.
  - `handleActionPost({})` (missing targetNode) returns 400 with message.
  - `handleActionPost(...)` returns 404 in release mode.
- [ ] T12 [T] US3 RED: extend the handlers test file:
  - `handleControlDeckPost({mockName: 'A'})` returns 200 with the injected payload when mock is registered.
  - `handleControlDeckPost({mockName: 'unknown'})` returns 404 with `availableMockNames`.
  - `handleControlDeckPost({})` returns 400.
  - `handleControlDeckPost(...)` returns 404 in release mode.
- [ ] T13 US1/2/3 GREEN: Implement `lib/src/mcp/xray_bridge/xray_bridge_handlers.dart` with `XRayBridgeResponse` + the three handlers + release-mode guard. Passes T10/T11/T12.

## Phase 7: Auth (User Story 5 — Localhost + Bearer Token, P3)

- [ ] T14 [T] US5 RED: Write `test/mcp/xray_bridge/xray_bridge_auth_test.dart`:
  - `XRayBridgeAuth.isLocalhost('127.0.0.1')` returns true.
  - `XRayBridgeAuth.isLocalhost('::1')` returns true.
  - `XRayBridgeAuth.isLocalhost('192.168.1.5')` returns false.
  - `XRayBridgeAuth.isLocalhost('10.0.0.1')` returns false.
  - `XRayBridgeAuth.validateBearerToken('abc', 'abc')` returns true.
  - `XRayBridgeAuth.validateBearerToken('abc', 'xyz')` returns false.
  - `XRayBridgeAuth.validateBearerToken('', 'xyz')` returns false.
  - `XRayBridgeAuth.validateBearerToken(null, 'xyz')` returns false when expected is set.
  - `XRayBridgeAuth.validateBearerToken(null, null)` returns false (no expected = no auth).
  - Constant-time comparison (no early-exit on first byte mismatch).
- [ ] T15 US5 GREEN: Implement `lib/src/mcp/xray_bridge/xray_bridge_auth.dart`. Passes T14.

## Phase 8: WebSocket Diff (User Story 4 — Real-Time Tree Diff, P2)

- [ ] T16 [T] US4 RED: Write `test/mcp/xray_bridge/xray_diff_test.dart`:
  - `XRayDiff.add(nodeId: 'n1', node: {...})` round-trips through `toJson`/`fromJson`.
  - `XRayDiff.remove(nodeId: 'n1')` round-trips.
  - `XRayDiff.update(nodeId: 'n1', before: {...}, after: {...})` round-trips.
  - `XRayDiffType` enum has `add`/`remove`/`update`.
- [ ] T17 US4 GREEN: Implement `lib/src/mcp/xray_bridge/xray_diff.dart`. Passes T16.
- [ ] T18 [T] US4 RED: Write `test/mcp/xray_bridge/xray_bridge_diff_stream_test.dart`:
  - `XRayBridgeDiffStream()` exposes a `Stream<XRayDiff>`.
  - `emitAdd(nodeId, node)` pushes an add diff to all subscribers.
  - `emitRemove(nodeId)` pushes a remove diff.
  - `emitUpdate(nodeId, before, after)` pushes an update diff.
  - Multiple subscribers all receive the diff (broadcast semantics).
  - In release mode, the stream is empty and emit* are no-ops.
- [ ] T19 US4 GREEN: Add the diff-stream class to `xray_diff.dart` (or a separate file). Passes T18.

## Phase 9: Release-strip Regression (User Story 5, FR-006, SC-004)

- [ ] T20 [T] US5 RED: Write `test/regression/issue_184_xray_bridge_release_strip_test.dart`:
  - `kXrayReleaseMode` is false in tests (compile-time constant).
  - `XRayBridgeHandlers(overlayState: ..., controlDeck: ..., isReleaseMode: true)` — `handleTreeGet` returns 404.
  - `handleActionPost(...)` returns 404 in release mode.
  - `handleControlDeckPost(...)` returns 404 in release mode.
  - `XRayBridgeDiffStream(isReleaseMode: true)` — stream is empty; `emitAdd` is a no-op.
- [ ] T21 US5 GREEN: Already implemented in earlier tasks; just ensure the regression test passes.

## Phase 10: Client URL Fix (spec compliance)

- [ ] T22 [T] RED: Write `test/mcp/capabilities/xray_capability_url_test.dart` (or extend existing):
  - `XrayCapability.triggerMock(mockName: 'A')` POSTs to `/xray/control-deck` (not `/xray/mock`).
  - The request body is `{"mockName": "A", "payload": null}`.
- [ ] T23 GREEN: Update `lib/src/mcp/capabilities/xray_capability.dart` — change `triggerMock` URL from `/xray/mock` to `/xray/control-deck`. Passes T22.

## Phase 11: Verify

- [ ] T24 Run `dart analyze` — no new errors/warnings.
- [ ] T25 Run `dart test` on the spec 035 scope — all green.
- [ ] T26 Write `specs/035-mcp-xray-bridge/tdd/verification.md`.
- [ ] T27 Commit + push + open PR (closes #184).
