# Feature Specification: Agent Plugin UI Render

**Feature Branch**: `023-agent-plugin-ui-render`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "agent plugin: ui.render tool + UI event channel + action-loop closure"

**Origin**: GitHub issue [#392](https://github.com/arrrrny/zuraffa/issues/392)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Agent Renders a UI Tree (Priority: P1)

An AI agent executing a mission calls `ui.render` with a component tree describing a product-offer card. The agent's output is replaced by a live, interactive UI rendered on the user's device — no fixed layout dictated by the host app.

**Why this priority**: This is the foundational capability. Without it, agents cannot author UI and the entire generative-UI loop has no starting point.

**Independent Test**: Can be fully tested by invoking a mission where the agent calls `ui.render` once with a valid tree. The user sees the rendered content on screen.

**Acceptance Scenarios**:

1. **Given** an agent mission is active and the agent receives a result to present, **When** the agent calls `ui.render` with a valid component tree, **Then** the tree is displayed on the user's device and the tool returns a success result including a view identifier.
2. **Given** a valid tree has been rendered, **When** the agent calls `ui.render` again with a different `replaceViewId`, **Then** the new tree replaces the previous view content without reloading the mission chrome.
3. **Given** a tree is partially streamed in, **When** intermediate nodes arrive before the full tree completes, **Then** the UI progressively renders each partial result so the user sees content building up.

---

### User Story 2 - User Interacts and Agent Responds (Priority: P1)

A user sees a rendered card with a "Select Offer" button. The user taps the button. That interaction is captured as a semantic action and routed back to the running agent as a tool result or steering message. The agent then continues its reasoning with the new context.

**Why this priority**: The interaction loop closure is what makes the rendered UI useful — without it the UI is display-only and the agent cannot react to user choices.

**Independent Test**: Can be tested by rendering a card with an action, tapping it, and verifying the agent receives the action payload and produces a follow-up response.

**Acceptance Scenarios**:

1. **Given** a rendered tree contains an interactive element with a semantic action ID, **When** the user taps that element, **Then** the action ID and its arguments are delivered to the agent as a tool result or steering message.
2. **Given** an action has been delivered to the agent, **When** the agent processes the action, **Then** the agent may call `ui.render` again to update the UI based on the user's choice.
3. **Given** a rendered tree contains multiple interactive elements, **When** the user taps any one of them, **Then** only that element's action is delivered (not a batch of all actions on screen).

---

### User Story 3 - Invalid Tree Produces a Typed Error (Priority: P2)

An agent calls `ui.render` with a tree that violates the vocabulary schema (unknown node type, invalid token, node count over the allowed cap). The tool returns a typed error describing exactly what is wrong so the agent can retry with a corrected tree.

**Why this priority**: Without structured error feedback the agent would produce unfixable invalid trees, stalling the mission.

**Independent Test**: Can be tested by calling `ui.render` with deliberately invalid trees (unknown node type, bad token value) and verifying each returns a descriptive error.

**Acceptance Scenarios**:

1. **Given** the agent calls `ui.render` with a tree containing an unrecognized node type, **When** the tree is validated, **Then** the tool returns an error indicating the unknown node type and the agent retries with a valid tree.
2. **Given** the agent calls `ui.render` with a tree exceeding the maximum allowed node count, **When** validation runs, **Then** the tool returns an error with the cap limit and the agent produces a simpler tree.
3. **Given** the agent calls `ui.render` with a valid tree, **When** validation passes, **Then** no error is returned and the view renders normally.

---

### User Story 4 - Vocabulary Narrowing per Mission Type (Priority: P2)

A listing-type mission restricts the agent's available component vocabulary to card variants only. The agent sees only the narrowed subset in its tool definition and cannot emit components outside that set.

**Why this priority**: Vocabulary narrowing ensures agents stay within brand and layout constraints per mission type, which is important for quality but not required for the initial working loop.

**Independent Test**: Can be tested by starting a listing mission and verifying the `ui.render` tool definition's input schema contains only card-type nodes.

**Acceptance Scenarios**:

1. **Given** a mission type declares a vocabulary constraint of card variants only, **When** the agent begins its mission, **Then** the `ui.render` tool input schema is narrowed to exclude non-card nodes.
2. **Given** a constrained vocabulary is active, **When** the agent attempts to emit a node outside the allowed subset, **Then** the tool returns a validation error referencing the constraint.

---

### User Story 5 - Risky Actions Gated by Policy (Priority: P2)

A rendered tree contains an action marked at the `confirm` tier (e.g., submitting a purchase). Before the action is delivered to the agent, the policy shell intercepts it and presents a user-confirmation prompt. The action proceeds only if the user approves.

**Why this priority**: Action gating protects users from unintended high-risk operations on generated UIs, which is a safety requirement before production use.

**Independent Test**: Can be tested by rendering a tree with a confirm-tier action, tapping it, and verifying a confirmation prompt appears before the action reaches the agent.

**Acceptance Scenarios**:

1. **Given** a rendered tree contains a `confirm`-tier action, **When** the user taps the action, **Then** a confirmation prompt is displayed before the action is routed to the agent.
2. **Given** the user declines the confirmation, **When** the decision is recorded, **Then** the action is not delivered to the agent and the UI remains unchanged.
3. **Given** the user approves the confirmation, **When** the approval is recorded, **Then** the action proceeds to the agent as if no gate existed.

---

### User Story 6 - Mission Ends with a Persistent Result View (Priority: P3)

A mission concludes and the final rendered tree persists as the result view. The user can return to it later, and the tree is available for replay or dashboard inspection.

**Why this priority**: Persistence is important for review and audit but not required for the initial interactive loop to function.

**Independent Test**: Can be tested by completing a mission and verifying the final rendered tree remains accessible after the mission ends.

**Acceptance Scenarios**:

1. **Given** a mission has ended, **When** the user navigates back to the mission result, **Then** the final rendered tree is displayed as it appeared at mission end.
2. **Given** a mission trace is recorded, **When** an operator inspects the trace, **Then** the rendered tree is available with its schema version and content hash.

---

### Edge Cases

- What happens when the agent calls `ui.render` before any mission is active? The tool returns a "no active mission" error.
- What happens when the agent emits an empty tree (no nodes)? The tool returns a validation error requiring at least one node.
- What happens when the user navigates away from a rendered view mid-mission? The agent continues processing; the UI re-renders the last tree when the user returns.
- What happens when two rapid `ui.render` calls race? The last call wins and replaces the view; earlier calls return `rendered: true` but their content is superseded.
- What happens when a `replaceViewId` references a view that no longer exists? The tool returns a "view not found" error and the agent renders without replacement.
- What happens when the agent emits a tree with tokens outside the allowed style set? The tool returns a typed error listing the invalid tokens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose a `ui.render` tool that accepts a component tree, an optional replacement view identifier, and an optional presentation hint, and returns a success result including a view identifier upon valid input.
- **FR-002**: The system MUST validate every `ui.render` call against the active UI Vocabulary Schema before dispatch, rejecting unknown node types, invalid token values, and node counts exceeding the allowed cap with typed errors.
- **FR-003**: The system MUST deliver rendered trees to the user interface via a streaming event channel, supporting progressive rendering where partial trees appear as they stream in.
- **FR-004**: The system MUST route user interactions on rendered trees (semantic action IDs and arguments) back to the agent as tool results or steering messages per the configured action routing policy.
- **FR-005**: The system MUST support vocabulary narrowing per mission type, restricting the `ui.render` tool's input schema to a declared subset of the full vocabulary.
- **FR-006**: The system MUST gate `confirm`-tier actions through a policy mechanism that requires explicit user approval before delivery to the agent.
- **FR-007**: The system MUST allow agent-rendered views to coexist with the host application's static chrome (navigation, sheets, tab bars) within the mission UI.
- **FR-008**: The system MUST record rendered trees in mission traces with a schema version and content hash for replay and dashboard inspection.

### Key Entities

- **UI Vocabulary Schema**: The canonical definition of allowed component nodes, tokens, and style variants available to the agent. Acts as the single source of truth for validation and tool input shaping.
- **Rendered View**: A live, interactive UI instance produced by the agent. Identified by a view identifier; may be replaced, composed with host chrome, or persisted as a mission result.
- **Semantic Action**: A user interaction captured from a rendered view, consisting of an action identifier and arguments. Routed back to the agent through configurable delivery mechanisms.
- **Mission Trace**: A record of a completed mission including the final rendered tree, its schema version, and content hash for audit and replay purposes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An agent can call `ui.render` with a valid tree and the user sees the rendered content on device within 2 seconds of the call completing.
- **SC-002**: A user interaction on a rendered tree (e.g., button tap) reaches the agent and the agent produces a follow-up UI update within 5 seconds end-to-end.
- **SC-003**: Invalid trees (bad tokens, unknown nodes, cap overflow) are rejected with descriptive errors 100% of the time, and the agent can successfully retry after correction.
- **SC-004**: Vocabulary narrowing is enforced per mission type — agents in constrained missions emit zero components outside the declared subset across all acceptance tests.

## Assumptions

- A UI Vocabulary Schema defining allowed nodes, tokens, and style variants already exists or will be delivered as a prerequisite (referenced as the shadcn-plugin issue dependency).
- The host application already has a mission UI shell capable of hosting dynamic content areas where rendered trees can be displayed.
- A policy shell with tiered action gating (safe / confirm) is available and integrated before this feature reaches production.
- The agent engine supports tool result delivery and can process semantic actions received as steering messages.
- Mission types that require vocabulary narrowing will declare their constraint sets via configuration, not code changes.
- Progressive rendering (partial tree display) is a desired UX improvement but the initial delivery may render only complete trees.
