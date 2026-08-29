# Implementation Plan: MCP Server X-Ray Bridge — Tree Inspection & Action Execution

**Branch**: `035-mcp-xray-bridge` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/035-mcp-xray-bridge/spec.md`

## Summary

This feature adds the pure-Dart half of the MCP Server X-Ray Bridge (v6 Track 4.4, issue #184). The pure-Dart half lives in this repository because the Zuraffa monorepo is split: the MCP server, the bridge contract (request/response shapes, validation rules, auth helpers, release-mode strip), and the existing `XrayCapability` client (which the MCP tools call) all live here; only the actual HTTP listener + WebSocket server (the `XRayBridgeServer` Flutter widget) lives in `zuraffa_flutter` and delegates to the pure-Dart handlers defined here.

The deliverable is therefore the **request/response data classes, the handler functions (which the Flutter `XRayBridgeServer` delegates to), the localhost + bearer-token auth helpers, the WebSocket diff model + diff-stream helper, and the release-mode strip** for the MCP X-Ray bridge. The actual HTTP listener lives in `zuraffa_flutter` and is not regenerated here.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`).

**Primary Dependencies**: `http` (already in pubspec for the MCP server). No new dependencies added.

**Storage**: In-memory only. The bridge holds no persistent state — it queries `XRayOverlayState` and `XRayControlDeck` (the registries defined in spec 036 and 034 respectively; on master, these are not yet present, so this PR's bridge handlers accept those registries as constructor params to avoid forward dependencies).

**Testing**: `package:test`. New tests in `test/plugins/xray/` and `test/regression/`.

**Target Platform**: Pure-Dart VM. The bridge handlers are testable without spinning up an HTTP server — they take `Map<String, dynamic>` requests and return `Map<String, dynamic>` responses + status codes.

**Project Type**: Library + CLI + codegen + MCP server.

**Performance Goals**: `GET /xray/tree` must serialize in <50ms (SC-001 budget is 2s; serialization is the data layer's only contribution). `POST /xray/action` lookup is O(1) via the registry's `Map<String, XRayNode>`.

**Constraints**: Zero `package:flutter` imports. Zero `/xray/*` endpoints reachable in release mode (FR-006 / SC-004) — enforced via the same `bool.fromEnvironment('dart.vm.product')` constant.

**Scale/Scope**: ~6 new lib files (handlers + models + auth + release guard), ~5 new test files. One existing file updated (`lib/src/mcp/capabilities/xray_capability.dart` — fix the `/xray/mock` URL to `/xray/control-deck` per spec FR-003).

## Constitution Check

1. **Library-First**: New code lives under `lib/src/mcp/xray_bridge/` as a standalone sub-package.
2. **CLI Interface**: The MCP tools (`xray_inspect`, `xray_triggerAction`, `xray_triggerMock`) already exist on master via `lib/src/mcp/v2_tools.dart`. This PR adds the handler contract those tools eventually call.
3. **Test-First (NON-NEGOTIABLE)**: Every behavior has a failing test before implementation.
4. **Integration Testing**: Contract tests for `XRayTreeResponse.toJson()` so the Flutter `XRayBridgeServer` (and the MCP `XrayCapability` client) consume the same shape.
5. **Simplicity**: No new dependencies. Pure-Dart data classes + handler functions + an auth helper. The WebSocket diff stream is a thin wrapper over `StreamController.broadcast()`.

All gates pass at design time.

## Project Structure

### Documentation (this feature)

```text
specs/035-mcp-xray-bridge/
├── spec.md              (input)
├── plan.md              (this file)
├── tasks.md
├── checklists/
│   └── requirements.md  (already exists)
└── tdd/
    ├── test-list.md
    ├── red/
    │   ├── 01-tree-response.md
    │   ├── 02-action-handler.md
    │   ├── 03-control-deck-handler.md
    │   ├── 04-websocket-diff.md
    │   ├── 05-auth-and-release-strip.md
    │   └── 06-client-url-fix.md
    └── verification.md
```

### Source code

```text
lib/src/mcp/xray_bridge/
├── xray_tree_response.dart         (NEW — XRayTreeResponse data class)
├── xray_action_request.dart        (NEW — XRayActionRequest / Response)
├── xray_control_deck_request.dart  (NEW — XRayControlDeckRequest / Response)
├── xray_diff.dart                  (NEW — XRayDiff WebSocket model)
├── xray_bridge_error.dart          (NEW — 404 + available ids helper)
├── xray_bridge_auth.dart           (NEW — localhost + bearer-token helpers)
└── xray_bridge_handlers.dart       (NEW — the actual handler functions)

lib/src/mcp/capabilities/
└── xray_capability.dart           (EXTENDED — fix /xray/mock → /xray/control-deck URL)

lib/src/core/
└── xray_config.dart                (EXTENDED — add kXrayReleaseMode constant)
```

### Tests

```text
test/mcp/xray_bridge/
├── xray_tree_response_test.dart
├── xray_action_request_test.dart
├── xray_control_deck_request_test.dart
├── xray_diff_test.dart
├── xray_bridge_handlers_test.dart
└── xray_bridge_auth_test.dart

test/regression/
└── issue_184_xray_bridge_release_strip_test.dart
```

## Goals & Strategy

### Primary goal

Add the pure-Dart contract + handlers for the MCP X-Ray bridge so that:
- The Flutter `XRayBridgeServer` (in `zuraffa_flutter`) delegates HTTP requests to pure-Dart handler functions defined here (`handleTreeGet`, `handleActionPost`, `handleControlDeckPost`).
- The handlers return structured `Map<String, dynamic>` + status code pairs.
- Unknown `targetNode` / `mockName` return 404 with available ids / names (FR-007, FR-008).
- All handlers return 404 in release mode (FR-006 / SC-004).
- Localhost + bearer-token auth helper (FR-005).
- WebSocket diff model + diff-stream helper (FR-004).

### Non-goals

- Implementing the actual HTTP server / WebSocket server (lives in `zuraffa_flutter`).
- Wiring the bridge into `AppShellBuilder` (out of scope; the codegen for the bridge server already exists on master).
- Implementing the XRayOverlayState / XRayControlDeck registries (specs 036 / 034 — separate PRs).
- Pagination of large trees (>10k nodes, spec edge case) — out of scope; the data layer supports it but the handler does not paginate (deferred).

### Strategy

1. **MVP slice (P1)**: `XRayTreeResponse`, `XRayActionRequest`/`Response`, `XRayControlDeckRequest`/`Response`, handler functions, 404-with-available-ids helper.
2. **WebSocket slice (P2)**: `XRayDiff` model + diff-stream helper.
3. **Auth slice (P3)**: localhost check + bearer-token constant-time compare.
4. **Release-strip regression (P3)**: 404 for all `/xray/*` endpoints in release mode.
5. **Client URL fix**: `XrayCapability.triggerMock` calls `/xray/control-deck` per spec instead of `/xray/mock`.

### Architecture

The handlers accept the overlay state + control deck as constructor params (typed loosely as `dynamic` to avoid forward dependencies on the spec 036 / 034 PRs). The handlers query those registries for the live tree and available mocks. This makes the handlers testable in isolation with fakes, AND compatible with whatever the spec 036 / 034 PRs eventually land.

### Risks

- **Risk**: the spec 036 / 034 PRs have not yet merged, so the bridge has nothing to query. **Mitigation**: the handlers accept the registries as `dynamic` constructor params and use `dynamic` dispatch (`registry.nodes`, `registry.inspect(id)`, `deck.inject(name)`, etc.). The handler unit tests use simple map-backed fakes that implement just enough of the surface.
- **Risk**: the existing `xray_capability.dart` calls `POST /xray/mock` but the spec says `POST /xray/control-deck`. **Mitigation**: this PR fixes the URL on the client side. The bridge server side (in `zuraffa_flutter`) must also expose `/xray/control-deck` — but that's a downstream package's responsibility, noted as deferred work.

## Changes

### Phase 1: Data models
- `XRayTreeResponse`, `XRayActionRequest`, `XRayControlDeckRequest`, `XRayDiff`.

### Phase 2: Handlers + 404 helper
- `XRayBridgeError.notFoundForNode(availableIds)`, `XRayBridgeError.notFoundForMock(availableNames)`.
- `XRayBridgeHandlers` class with `handleTreeGet`, `handleActionPost`, `handleControlDeckPost`.

### Phase 3: Auth + release strip
- `XRayBridgeAuth.isLocalhost(address)`, `XRayBridgeAuth.validateBearerToken(received, expected)`.
- Release-mode guard in `XRayBridgeHandlers` constructor.

### Phase 4: WebSocket diff stream
- `XRayDiff` model.
- `XRayBridgeDiffStream` — wraps a `StreamController<XRayDiff>.broadcast()`.

### Phase 5: Client URL fix
- `xray_capability.dart`: `triggerMock` URL `/xray/mock` → `/xray/control-deck`.

### Phase 6: Verify
- Run `dart analyze` + `dart test`.
- Write `tdd/verification.md`.

## Sketch

### XRayTreeResponse

```dart
class XRayTreeResponse {
  final String? activeView;       // null when no view mounted
  final List<Map<String, dynamic>> nodes;  // flat or hierarchical
  const XRayTreeResponse({this.activeView, this.nodes = const []});
  Map<String, dynamic> toJson();
}
```

### XRayBridgeHandlers

```dart
class XRayBridgeHandlers {
  final dynamic overlayState;   // spec 036 — XRayOverlayState
  final dynamic controlDeck;    // spec 034 — XRayControlDeck
  final bool _isReleaseMode;
  XRayBridgeHandlers({
    required this.overlayState,
    required this.controlDeck,
    bool? isReleaseMode,
  });

  XRayBridgeResponse handleTreeGet();
  XRayBridgeResponse handleActionPost(Map<String, dynamic> body);
  XRayBridgeResponse handleControlDeckPost(Map<String, dynamic> body);
}

class XRayBridgeResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  const XRayBridgeResponse(this.statusCode, this.body);
}
```

### XRayBridgeAuth

```dart
class XRayBridgeAuth {
  static bool isLocalhost(String remoteAddress);
  static bool validateBearerToken(String received, String expected);
}
```

## Deferred / Future Work

- **HTTP/WebSocket server**: the actual `HttpServer.bind` + WebSocket upgrade lives in `zuraffa_flutter`'s `XRayBridgeServer`.
- **Spec 036 / 034 wiring**: once those PRs merge, the `XRayBridgeHandlers` constructor will accept typed `XRayOverlayState` and `XRayControlDeck` instead of `dynamic`.
- **Large-tree pagination**: >10k nodes edge case.
- **Concurrent action serialization**: `POST /xray/action` while another action is in flight (HTTP 409 Conflict per spec edge case) — deferred.
