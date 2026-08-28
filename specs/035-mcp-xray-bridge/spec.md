# Feature Specification: MCP Server X-Ray Bridge

**Feature Branch**: `035-mcp-xray-bridge`

**Created**: 2026-08-28

**Status**: Draft

**Input**: "[v6] Track 4.4 — MCP Server X-Ray Bridge: Tree Inspection & Action Execution". This feature originates from GitHub issue #184 (https://github.com/arrrrny/zuraffa/issues/184). Build an MCP Server X-Ray Bridge for tree inspection and action execution in v6.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Inspect Live UI Tree via MCP (Priority: P1)

An AI agent (e.g., Claude, Copilot) connects to the running Zuraffa app through the MCP bridge and retrieves the full X-Ray tree as structured JSON. The agent can see every node's id, type, state, bound actions, and parent-child relationships — giving it a complete, real-time DOM of the Flutter widget hierarchy.

**Why this priority**: Without the ability to inspect the tree, no downstream action or testing capability is possible. This is the foundational read primitive.

**Independent Test**: Can be fully tested by sending `GET /xray/tree` to the MCP server and verifying the JSON response contains activeView, all node ids, types, states, and child relationships. Delivers immediate value: an agent can understand the UI without guessing.

**Acceptance Scenarios**:

1. **Given** the Zuraffa app is running with X-Ray enabled and at least one view is mounted, **When** the agent sends `GET /xray/tree`, **Then** the response is valid JSON containing `activeView`, an array of nodes each with `id`, `type`, `state`, `boundAction`, and `children`.
2. **Given** the app is running with X-Ray enabled, **When** the agent sends `GET /xray/tree` and then navigates to a different screen, **When** the agent sends `GET /xray/tree` again, **Then** the response reflects the new activeView and updated node set.
3. **Given** the app is running but no views are mounted, **When** the agent sends `GET /xray/tree`, **Then** the response returns an empty tree with `activeView: null` and no error.

---

### User Story 2 — Trigger Actions Programmatically (Priority: P1)

An AI agent inspects the tree, identifies a button node with a bound action, and fires that action via MCP. The app executes the bound callback as if a user tapped the button — enabling AI-driven E2E testing without relying on Flutter's `find.byKey()` or pixel coordinates.

**Why this priority**: Action execution is the core write primitive that makes AI-driven E2E testing possible. Without it, the bridge is read-only and of limited use for automated testing.

**Independent Test**: Can be fully tested by sending `POST /xray/action` with a valid nodeId and verifying the bound action executes (observable via side effect, e.g., state change, navigation). Delivers end-to-end value: inspect → act → verify.

**Acceptance Scenarios**:

1. **Given** the agent has retrieved the tree and identified a node with `boundAction`, **When** the agent sends `POST /xray/action` with `targetNode` set to that node's id, **Then** the bound action is invoked and the app state changes accordingly.
2. **Given** the agent sends `POST /xray/action` with a `targetNode` id that does not exist in the current tree, **Then** the server responds with HTTP 404 and a body listing all currently available node ids.
3. **Given** the agent sends `POST /xray/action` with a valid node id but the node has no `boundAction`, **Then** the server responds with HTTP 400 and a message indicating the node has no bound action.

---

### User Story 3 — Trigger Synthetic Mocks via Control Deck (Priority: P2)

An AI agent sends a mock name through the MCP bridge, and the app injects that mock state into the running XRayScope — the same operation as pressing a button in the Control Deck. This lets agents set up specific test scenarios (e.g., "Expired Product", "Empty Cart") without manual UI interaction.

**Why this priority**: Mock injection is critical for deterministic E2E testing but depends on the tree inspection and action primitives being solid first.

**Independent Test**: Can be fully tested by sending `POST /xray/control-deck` with a mock name and verifying the app transitions to that mock state. Delivers value: agents can set up any scenario.

**Acceptance Scenarios**:

1. **Given** the app has registered mock presets, **When** the agent sends `POST /xray/control-deck` with a valid `mockName`, **Then** the app transitions to the corresponding mock state and the next `GET /xray/tree` reflects the change.
2. **Given** the agent sends `POST /xray/control-deck` with an unrecognized `mockName`, **Then** the server responds with HTTP 404 and a list of available mock names.

---

### User Story 4 — Real-Time Tree Diff via WebSocket (Priority: P2)

An AI agent opens a WebSocket connection and receives pushed tree diffs whenever the UI state changes — node added, removed, or state updated — without polling. This enables reactive, event-driven testing workflows.

**Why this priority**: Polling is functional but wasteful and slow. WebSocket push enables efficient real-time monitoring.

**Independent Test**: Can be fully tested by opening a WebSocket, triggering a UI state change, and verifying the agent receives a diff payload. Delivers value: agents react instantly to UI changes.

**Acceptance Scenarios**:

1. **Given** the agent has an open WebSocket connection, **When** a node is added to the X-Ray tree, **Then** the agent receives a diff message containing the new node and its parent relationship.
2. **Given** the agent has an open WebSocket connection, **When** a node's state changes, **Then** the agent receives a diff message with the nodeId, previous state, and new state.

---

### User Story 5 — Secure Localhost Binding with Token Auth (Priority: P3)

The MCP X-Ray endpoints are accessible only on localhost when running in dev mode. For remote access, a configurable bearer token must be provided. X-Ray endpoints are never exposed in release mode.

**Why this priority**: Security is non-negotiable but is a guardrail, not a feature. It should be enforced from the start but is not the primary value.

**Independent Test**: Can be tested by verifying that requests from non-localhost addresses are rejected without a valid token, and that no X-Ray endpoints respond when the app is in release mode.

**Acceptance Scenarios**:

1. **Given** the app is in dev mode, **When** a request is made from `127.0.0.1` to any `/xray/*` endpoint, **Then** the request is handled normally.
2. **Given** the app is in dev mode, **When** a request is made from a non-localhost address without a token, **Then** the server responds with HTTP 403.
3. **Given** the app is in dev mode, **When** a request is made with a valid bearer token, **Then** the request is handled normally regardless of source address.
4. **Given** the app is in release mode, **When** any request is made to any `/xray/*` endpoint, **Then** the server responds with HTTP 404 (endpoints do not exist).

---

### Edge Cases

- What happens when the WebSocket connection drops mid-stream? The bridge should buffer diffs and replay missed state on reconnect.
- What happens when `POST /xray/action` is called while the target view is being torn down (e.g., during navigation)? The server should return HTTP 409 Conflict.
- What happens when multiple agents call `POST /xray/action` concurrently on the same node? The system should serialize action execution to prevent race conditions.
- What happens when the X-Ray tree exceeds a reasonable size (e.g., >10,000 nodes)? The tree endpoint should support pagination or filtering to keep payloads manageable.
- What happens when a mock name matches multiple registered mocks? The system should return the most specific match or return HTTP 300 Multiple Choices.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST expose an MCP endpoint `GET /xray/tree` that returns the current X-Ray tree as structured JSON, including activeView, all nodes with id, type, state, boundAction, and child relationships.
- **FR-002**: System MUST expose an MCP endpoint `POST /xray/action` that accepts a `targetNode` id and optional `payload`, finds the corresponding XRayNode, and invokes its boundAction.
- **FR-003**: System MUST expose an MCP endpoint `POST /xray/control-deck` that accepts a `mockName` string and injects the corresponding synthetic mock state into the active XRayScope.
- **FR-004**: System MUST provide a WebSocket bridge that pushes tree diff payloads to connected clients whenever the X-Ray tree structure or node state changes.
- **FR-005**: System MUST bind all `/xray/*` endpoints to localhost only in dev mode; remote access MUST require a valid bearer token.
- **FR-006**: System MUST NOT expose any `/xray/*` endpoints when the app is in release mode.
- **FR-007**: System MUST return HTTP 404 with a list of available node ids when `POST /xray/action` receives an unrecognized targetNode.
- **FR-008**: System MUST return HTTP 404 with a list of available mock names when `POST /xray/control-deck` receives an unrecognized mockName.

### Key Entities

- **XRayTreeResponse**: Represents the full X-Ray tree snapshot — contains activeView identifier and a flat or hierarchical list of XRayNode entries.
- **XRayNode**: Represents a single node in the X-Ray tree — has id, type (widget kind), state (current state values), boundAction (optional action reference), and parent-child relationships.
- **XRayDiff**: Represents a single change to the X-Ray tree — contains the change type (add/remove/update), the affected nodeId, and the before/after state.
- **ActionRequest**: Represents a request to trigger a bound action — contains targetNode id and an optional payload object.
- **ControlDeckRequest**: Represents a request to inject a mock — contains the mockName string.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An AI agent can inspect the live UI tree and identify all interactive elements within 2 seconds of sending `GET /xray/tree`.
- **SC-002**: An AI agent can trigger any bound action via `POST /xray/action` with 100% accuracy — the correct action fires for the given nodeId.
- **SC-003**: An AI agent can complete a full E2E flow (inspect tree → identify button → trigger action → verify state change) in under 10 seconds.
- **SC-004**: Zero X-Ray endpoints are accessible in release mode; all endpoints are unreachable and return 404.

## Assumptions

- Track 4.1 (XRayScope/XRayNode), Track 4.2 (Visual Overlay), and Track 4.3 (Control Deck) are already implemented and available as dependencies.
- The existing MCP Server (Track 5.2) provides the base HTTP/WebSocket infrastructure that this feature extends with X-Ray-specific routes.
- The X-Ray tree is already serializable — XRayScope and XRayNode expose the data needed for JSON serialization without additional adaptation.
- The WebSocket bridge reuses the existing MCP server's WebSocket transport rather than implementing a separate channel.
- Dev mode detection is already available via the app's build configuration or runtime mode flag.
- Authentication token configuration follows the existing MCP server's auth pattern (environment variable or config file).
