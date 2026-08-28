# Feature Specification: X-Ray Visual Overlay with Bounding Boxes

**Feature Branch**: `specs/036-xray-visual-overlay`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "[v6] Track 4.2 — X-Ray Visual Overlay with Bounding Boxes: This feature originates from GitHub issue #181 (https://github.com/arrrrny/zuraffa/issues/181). Add an X-Ray Visual Overlay that draws bounding boxes over UI for v6."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Activate X-Ray Overlay (Priority: P1)

As a developer running the app in debug or profile mode, I want to activate an X-Ray visual overlay so that I can see bounding boxes rendered over every registered XRayNode in the UI.

**Why this priority**: This is the core entry point — without activation the entire feature is invisible. Shake gesture and CLI toggle are the two activation paths; both must work for the feature to be usable at all.

**Independent Test**: Can be fully tested by shaking the device (or using the CLI) in debug mode and verifying that the overlay layer appears above all widgets with bounding boxes around registered nodes.

**Acceptance Scenarios**:

1. **Given** the app is running in debug or profile mode, **When** the user shakes the device, **Then** the X-Ray overlay activates: the background dims and neon bounding boxes appear around every XRayNode.
2. **Given** the app is running in debug or profile mode, **When** the developer runs `zfa xray enable`, **Then** the X-Ray overlay activates identically to the shake gesture.
3. **Given** the X-Ray overlay is active, **When** the user shakes the device again (or runs `zfa xray disable`), **Then** the overlay deactivates and the screen returns to its normal appearance.
4. **Given** the app is running in release mode, **When** the developer attempts any X-Ray activation, **Then** nothing happens — no overlay renders, no activation code path executes.

---

### User Story 2 — Inspect Individual Nodes (Priority: P2)

As a developer with the X-Ray overlay active, I want to tap on a bounding box to see a detail panel showing the full state JSON for that node, so I can debug its SignalSlice state without code changes.

**Why this priority**: Node inspection is the primary value-add of X-Ray mode — seeing boxes alone is useful, but inspecting state is what saves debugging time.

**Independent Test**: Can be tested by activating the overlay, tapping a bounding box, and verifying a detail panel opens with the correct nodeId, status, and state data.

**Acceptance Scenarios**:

1. **Given** the X-Ray overlay is active, **When** the user taps on a bounding box, **Then** a detail panel opens showing the node's full state JSON, nodeId, enabled/disabled status, and bound action names.
2. **Given** the X-Ray overlay is active, **When** the user taps in an area with no bounding box, **Then** the touch passes through to the underlying app widget and does not open any panel.

---

### User Story 3 — Bounding Box Information Display (Priority: P2)

As a developer with the X-Ray overlay active, I want each bounding box to display at-a-glance information (nodeId, enabled/disabled status, bound action name, SignalSlice state summary) so I can quickly scan the UI without tapping every node.

**Why this priority**: The overlay's value is proportional to how much information is visible at a glance; without inline labels, the developer must tap every box.

**Independent Test**: Can be tested by activating the overlay and visually verifying that each bounding box shows the required labels in the correct format.

**Acceptance Scenarios**:

1. **Given** the X-Ray overlay is active, **When** the developer views any bounding box, **Then** it displays the nodeId (e.g., `ProfileViewNode.editProfileButton`), current status (`enabled` or `disabled`), bound action name (e.g., `onEditTapped`), and a summary of the SignalSlice state (data/error/loading indicators).
2. **Given** the X-Ray overlay is active, **When** a node's SignalSlice state changes, **Then** the bounding box labels update to reflect the new state without requiring overlay re-activation.

---

### User Story 4 — CLI Toggle Lifecycle (Priority: P3)

As a developer, I want to control X-Ray overlay via CLI commands (`zfa xray enable` / `zfa xray disable`) so I can toggle the overlay without physically shaking the device.

**Why this priority**: CLI control is valuable for automation and remote debugging, but is secondary to the shake gesture for immediate interactive use.

**Independent Test**: Can be tested by running the CLI commands and verifying overlay state changes on a connected device or emulator.

**Acceptance Scenarios**:

1. **Given** the app is running in debug or profile mode, **When** the developer runs `zfa xray enable`, **Then** the overlay activates.
2. **Given** the X-Ray overlay is active, **When** the developer runs `zfa xray disable`, **Then** the overlay deactivates.
3. **Given** the app is running in release mode, **When** the developer runs `zfa xray enable`, **Then** the command completes without error but no overlay appears.

---

### Edge Cases

- What happens when there are no registered XRayNodes in the current view? The overlay should still activate (dimmed background) but show no bounding boxes.
- What happens when a node is removed from the widget tree while the overlay is active? Its bounding box should disappear on the next render cycle without crashing the overlay.
- What happens when the device is shaken rapidly multiple times? The overlay should toggle cleanly without double-activation or state corruption.
- What happens when the app transitions between routes while the overlay is active? The overlay should re-render bounding boxes for nodes in the new route.
- What happens when SignalSlice state for a node is null or incomplete? The bounding box should display gracefully with "N/A" or empty values, never crash.
- What happens when two overlapping nodes both have bounding boxes? The topmost node's bounding box should be tappable and inspectable; underlying boxes should still render their labels.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST render a visual overlay layer above all app widgets when X-Ray mode is activated, dimming the background to provide contrast for bounding boxes.
- **FR-002**: System MUST draw neon-colored bounding boxes over every registered XRayNode, with distinct colors per view type to aid visual differentiation.
- **FR-003**: Each bounding box MUST display inline labels: nodeId, enabled/disabled status, bound action name, and a summary of the current SignalSlice state (data/error/loading).
- **FR-004**: System MUST support X-Ray mode activation via device shake gesture and via `zfa xray enable` / `zfa xray disable` CLI commands.
- **FR-005**: System MUST pass through touches that do not land on a bounding box to the underlying app UI, ensuring the app remains interactive while the overlay is visible.
- **FR-006**: Tapping a bounding box MUST open a detail panel showing the full state JSON for the tapped node, including its complete SignalSlice data, error, and loading state.
- **FR-007**: System MUST compile and execute NO X-Ray code paths in release mode — the overlay must be fully stripped or disabled so there is zero runtime cost in production.
- **FR-008**: System MUST update bounding box labels in real time as SignalSlice state changes, without requiring overlay re-activation.

### Key Entities

- **XRayOverlay**: The visual layer rendered above all widgets; manages bounding box lifecycle, dimmed background, and touch passthrough logic.
- **XRayBoundingBox**: A single bounding box rendered for an XRayNode; holds inline label data (nodeId, status, action, state summary) and opens a detail panel on tap.
- **XRayDetailPanel**: A panel shown on tap-to-inspect, displaying the full state JSON for the tapped node.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can activate the X-Ray overlay via shake gesture within 1 second and see bounding boxes over all registered nodes in the current view.
- **SC-002**: Each bounding box displays nodeId, status, bound action, and state summary without requiring any tap or additional interaction.
- **SC-003**: Tap-to-inspect opens a detail panel within 200ms showing complete node state data, and touch passthrough works correctly for non-bounding-box areas.
- **SC-004**: Zero X-Ray-related code executes in release mode builds — no overlay rendering, no gesture listeners, no CLI handlers.

## Assumptions

- The app runs in debug or profile mode for X-Ray overlay to function; release mode is explicitly excluded.
- Track 4.1 (XRayScope/XRayNode infrastructure) is already implemented and provides the registered node registry and SignalSlice state that this feature visualizes.
- The app uses a standard overlay mechanism (e.g., Flutter OverlayEntry or equivalent) that allows rendering above all widgets.
- Device shake gestures are available on the target platform (iOS and Android) and are detectable by the runtime.
- CLI commands (`zfa xray enable` / `zfa xray disable`) communicate with a running app instance via an existing command transport mechanism.
- Bounding box visual styling (neon colors, distinct per view) is a design detail to be finalized during implementation; the spec defines WHAT to display, not the exact color palette.
