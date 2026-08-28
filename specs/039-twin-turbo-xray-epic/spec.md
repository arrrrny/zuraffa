# Feature Specification: Twin Turbo X-Ray — AI-Native Debugging & Agent Bridge

**Feature Branch**: `039-twin-turbo-xray-epic`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "[v6 EPIC] Twin Turbo X-Ray: AI-Native Debugging & Agent Bridge: This feature originates from GitHub issue #165 (https://github.com/arrrrny/zuraffa/issues/165). Epic: Twin Turbo X-Ray — AI-native debugging and an agent bridge for v6."

## User Scenarios & Testing

### User Story 1 — Deterministic Widget ID Infrastructure (Priority: P1)

As a Zuraffa developer, every widget in the tree is assigned a deterministic, stable ID that survives rebuilds and navigation, enabling reliable external tooling.

**Why this priority**: Without stable IDs, none of the downstream X-Ray features (overlay, control deck, MCP bridge) can function. This is the foundational layer.

**Independent Test**: Can be fully verified by rendering a widget tree and asserting every node has a predictable, non-null ID that remains stable across hot reloads.

**Acceptance Scenarios**:

1. **Given** a widget tree is built, **When** the tree is rendered, **Then** every widget node receives a deterministic ID derived from its type and position in the hierarchy.
2. **Given** a widget tree undergoes a hot reload, **When** the tree is re-rendered, **Then** existing nodes retain their previous IDs and new nodes receive new IDs without collisions.
3. **Given** two identical widget subtrees exist at different positions, **When** both are rendered, **Then** their child nodes receive distinct IDs.

---

### User Story 2 — Visual Overlay for Humans (Priority: P2)

As a Zuraffa developer, I can toggle a visual overlay that draws bounding boxes and ID labels over every widget in the running app so I can visually inspect the tree.

**Why this priority**: The overlay is the primary human-facing debugging tool and validates the ID infrastructure from P1.

**Independent Test**: Can be tested by enabling the overlay on a running app and visually confirming bounding boxes and labels appear correctly over all visible widgets.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the developer activates the X-Ray overlay, **Then** bounding boxes are drawn around every rendered widget with its ID label visible.
2. **Given** the overlay is active, **When** the developer navigates to a different screen, **Then** the overlay updates to reflect the new widget tree in real time.
3. **Given** the overlay is active, **When** the developer taps on a widget's bounding box, **Then** the overlay highlights the selected widget and displays its properties (type, ID, state).

---

### User Story 3 — Control Deck: Mock Decorator & Synthetic Payload Injector (Priority: P2)

As a Zuraffa developer, I can annotate widgets with a mock decorator that intercepts data sources and injects synthetic payloads for deterministic E2E testing without a real backend.

**Why this priority**: Synthetic testing eliminates flaky tests and enables CI/CD confidence. Complements the overlay but can be tested independently.

**Independent Test**: Can be tested by decorating a widget with a mock decorator, providing synthetic data, and asserting the widget renders correctly without any network calls.

**Acceptance Scenarios**:

1. **Given** a widget is annotated with a mock decorator, **When** the app renders that widget, **Then** the widget receives synthetic data from the decorator instead of its normal data source.
2. **Given** the control deck is active, **When** the developer modifies a synthetic payload at runtime, **Then** the affected widget re-renders with the updated data.
3. **Given** the control deck is active, **When** a test scenario is executed, **Then** all decorated widgets report their received payloads for assertion.

---

### User Story 4 — MCP Server X-Ray Bridge (Priority: P1)

As an AI agent connected via MCP, I can inspect the full widget tree, read widget properties, tap elements, and execute actions on the running app through the MCP bridge.

**Why this priority**: This is the core of the "agent bridge" capability — it unlocks AI-native debugging and autonomous testing workflows. Along with P1 (IDs), it forms the MVP.

**Independent Test**: Can be tested by connecting an MCP client, issuing tree-inspection commands, and asserting correct tree data is returned with stable IDs.

**Acceptance Scenarios**:

1. **Given** an MCP client is connected to the Zuraffa app, **When** the client requests the widget tree, **Then** the full tree with deterministic IDs and widget metadata is returned.
2. **Given** an MCP client has the widget tree, **When** the client issues a tap action targeting a specific widget ID, **Then** the app performs the tap on that exact widget.
3. **Given** an MCP client is connected, **When** the client issues a scroll or text-entry action, **Then** the app executes the action on the targeted widget and returns the resulting state.
4. **Given** multiple apps are running, **When** the MCP client connects, **Then** the client can select which app to interact with via the DTD connection.

---

### Edge Cases

- What happens when a widget tree changes between the time the agent reads it and the time it issues an action? The system MUST handle stale-widget errors gracefully and return the current tree state.
- What happens when a mock decorator conflicts with a real data source at the same position? The system MUST apply the mock and log a warning that real data was suppressed.
- What happens when the visual overlay is active on a widget tree with thousands of nodes? The system MUST render without visible frame drops (target ≤16ms per frame).
- What happens when an MCP client issues an action on a widget that no longer exists? The system MUST return a "widget not found" error with the last-known tree snapshot.
- What happens when two MCP clients connect simultaneously? The system MUST support concurrent read-only tree inspection but serialize write actions (tap, scroll, input).

## Requirements

### Functional Requirements

- **FR-001**: System MUST assign a deterministic, unique ID to every widget in the tree based on its type and hierarchy position, surviving hot reloads.
- **FR-002**: System MUST expose a visual overlay mode that renders bounding boxes and ID labels over all visible widgets in the running app.
- **FR-003**: System MUST support a mock decorator that intercepts data sources at the widget level and injects synthetic payloads for testing.
- **FR-004**: System MUST expose an MCP server interface that allows external clients to read the widget tree, inspect widget properties, and execute actions (tap, scroll, text input).
- **FR-005**: System MUST handle stale-widget references gracefully, returning current tree state when a referenced widget no longer exists.
- **FR-006**: System MUST log all mock interceptions and synthetic data injections for debugging and audit purposes.
- **FR-007**: System MUST support the Control Deck for runtime payload modification without requiring a full app restart.

### Key Entities

- **XRayScope**: The root container that instruments the widget tree, assigning deterministic IDs to all descendant nodes.
- **XRayNode**: A single instrumented node in the widget tree carrying its deterministic ID, type metadata, and current state.
- **XRayMock Decorator**: An annotation that marks a widget for data interception, specifying the synthetic payload source.
- **XRay Bridge (MCP)**: The MCP server endpoint that translates external agent commands into widget-tree reads and actions on the running app.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Every widget in a rendered tree has a deterministic, non-null ID that survives hot reload with zero ID collisions.
- **SC-002**: The visual overlay renders at ≤16ms per frame on a tree with up to 5,000 widgets, with no dropped frames.
- **SC-003**: An MCP client can read the full widget tree and execute a tap action on a target widget in under 500ms round-trip.
- **SC-004**: Mock-decorated widgets receive synthetic payloads with zero unintended network calls, verified by mock-mode tests.

## Assumptions

- The DDA Foundation (issue #172) is available for XRayMock decorator scanning.
- ControlledWidget (issue #173) is available as the wrapping primitive for XRayScope.
- The MCP server infrastructure (existing Zuraffa MCP server in `bin/`) is the transport for the X-Ray bridge.
- The feature targets Zuraffa v6 running on Flutter; web support is out of scope for the initial epic.
- Visual overlay is a debug-mode-only feature and must not ship in production builds.
