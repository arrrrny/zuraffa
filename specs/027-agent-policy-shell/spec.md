# Feature Specification: Agent Policy Shell

**Feature Branch**: `027-agent-policy-shell`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "agent: policy shell — ToolGatingHook, MissionBudgetHook, MissionTraceRecorder"

**Origin**: GitHub issue [#387](https://github.com/arrrrny/zuraffa/issues/387)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tool Permission Gating (Priority: P1)

As an agent operator, I want the system to gate which tools an agent may call based on risk level, so that high-risk actions either require my explicit approval or are blocked entirely, preventing unauthorized or dangerous tool invocations.

**Why this priority**: Tool gating is the foundational safety mechanism. Without it, agents can freely call any tool regardless of risk, making the policy shell ineffective. This is the core trust boundary.

**Independent Test**: Can be fully tested by configuring a permission registry with safe, confirm, and admin risk levels, then attempting tool calls at each level. Safe calls auto-execute, confirm calls block until approved (and deny on timeout), admin calls deny for non-internal missions.

**Acceptance Scenarios**:

1. **Given** a tool registered as `safe` risk, **When** the agent calls it, **Then** the tool executes automatically without user intervention.
2. **Given** a tool registered as `confirm` risk, **When** the agent calls it, **Then** the system emits a typed UI approval request and blocks execution until the user approves or denies.
3. **Given** a tool registered as `confirm` risk and a UI approval request has been emitted, **When** the user does not respond within a configurable timeout, **Then** the tool call is denied and the agent receives a denial result.
4. **Given** a tool registered as `admin` risk, **When** the agent calls it from a non-internal mission, **Then** the tool call is denied immediately without a UI prompt.
5. **Given** a tool registered as `admin` risk, **When** the agent calls it from an internal mission, **Then** the tool executes without user intervention.
6. **Given** a tool not present in the permission registry, **When** the agent calls it, **Then** the system falls back to the tool's own risk metadata (if available), otherwise defaults to `safe` behavior.
7. **Given** a mission with a per-mission tool allowlist, **When** the agent calls a tool not in the allowlist, **Then** the tool call is denied regardless of the tool's risk level.

---

### User Story 2 - Mission Budget Enforcement (Priority: P2)

As an agent operator, I want the system to enforce spending budgets on missions so that a misbehaving or runaway agent cannot consume unlimited resources (tool calls, time, tokens, or per-tool-class durations).

**Why this priority**: Budget enforcement prevents resource exhaustion. Without it, a stuck or looping agent can exhaust API quotas, burn compute time, or run indefinitely. This is the economic safety net.

**Independent Test**: Can be fully tested by configuring budgets (max calls, max wall-clock, max tokens, max per-tool-class seconds) and running a mission that exceeds each limit, verifying the mission is cancelled with a typed budget-exceeded event for each case.

**Acceptance Scenarios**:

1. **Given** a mission with a maximum tool-call budget of 10, **When** the agent attempts an 11th tool call, **Then** the mission is cancelled and a budget-exceeded event is emitted with the tool-call limit reason.
2. **Given** a mission with a maximum wall-clock budget of 60 seconds, **When** the mission exceeds 60 seconds of elapsed time, **Then** the mission is cancelled and a budget-exceeded event is emitted with the time-limit reason.
3. **Given** a mission with a maximum token budget, **When** the cumulative token usage across all model interactions exceeds the budget, **Then** the mission is cancelled and a budget-exceeded event is emitted with the token-limit reason.
4. **Given** a mission with a maximum per-tool-class duration (e.g., 30 seconds of webview usage), **When** the cumulative duration for that tool class exceeds the budget, **Then** the mission is cancelled and a budget-exceeded event is emitted with the per-tool-class reason.
5. **Given** a mission where no budget limit has been exceeded, **When** the mission completes, **Then** no budget-exceeded event is emitted and the mission finishes normally.

---

### User Story 3 - Mission Trace Recording (Priority: P2)

As an agent operator, I want every mission to produce a complete, replayable trace of what the agent did — which tools were called, with what arguments, for how long, and what the outcome was — so I can audit, debug, and evaluate agent behavior.

**Why this priority**: Trace recording provides observability and auditability. Without it, agent behavior is opaque, making it impossible to evaluate performance, debug failures, or verify compliance. This is the foundation for the eval harness.

**Independent Test**: Can be fully tested by running a 5-tool mission and verifying the output trace JSON contains a complete record of all tool calls with hashed arguments, timing, status, token usage, provider, and outcome.

**Acceptance Scenarios**:

1. **Given** a mission with 5 tool calls, **When** the mission completes, **Then** the trace contains exactly 5 tool-call entries, each with the tool name, arguments hash, wall-clock duration, status, and token usage.
2. **Given** a tool call with arguments, **When** the trace records the call, **Then** the arguments are stored as a hash (not the raw values) unless the field is in an explicit allowlist of safe fields.
3. **Given** a running mission, **When** the agent is processing a streaming response, **Then** the trace recorder maintains correctness under concurrent streaming events without corruption or data loss.
4. **Given** a completed mission trace, **When** the trace is consumed by an evaluation harness, **Then** the trace JSON conforms to the agreed schema and can be replayed to reconstruct the mission's behavior.
5. **Given** a completed mission trace, **When** the trace is inspected, **Then** it contains no personally identifiable information (PII) — all argument values are hashed unless explicitly allowlisted.

---

### User Story 4 - Oversized Tool Result Guard (Priority: P2)

As an agent operator, I want the system to intercept oversized tool results before they enter model context, so that large payloads are stored as references rather than consuming model context window or causing performance degradation.

**Why this priority**: Oversized results can exhaust model context windows, cause latency spikes, or crash the agent loop. This is a practical resource-protection mechanism that pairs with the budget system.

**Independent Test**: Can be fully tested by simulating a 2 MB tool result and verifying it is stored as an artifact reference (not embedded in model context) while still being available for retrieval.

**Acceptance Scenarios**:

1. **Given** a tool returning a 2 MB result, **When** the result is processed by the guard, **Then** the result entering model context is replaced with a compact artifact reference, and the full result is stored externally.
2. **Given** a tool returning a result within the size threshold, **When** the result is processed by the guard, **Then** the result enters model context unmodified.
3. **Given** a tool result that was guarded as an artifact reference, **When** the mission trace records the tool call, **Then** the trace entry references the artifact rather than embedding the full result.

---

### Edge Cases

- What happens when the permission registry contains conflicting entries for the same tool (e.g., registered as both `safe` and `confirm`)? The most restrictive risk level wins.
- What happens when a tool's own risk metadata conflicts with the registry? The registry takes precedence over the tool's self-declared metadata.
- What happens when the mission object is missing budget defaults? System-level sane defaults are applied (configurable but with reasonable initial values).
- What happens when the trace recorder encounters a tool call that completes before the recorder subscribes? The recorder must be initialized before the first tool call or it will miss events.
- What happens when the budget is set to zero for a specific category? No tool calls / no time / no tokens are permitted — the mission cancels immediately on the first attempt.
- What happens when multiple budget limits are breached simultaneously? The system emits one budget-exceeded event per breached limit and cancels the mission on the first breach detected.
- What happens when the artifact reference storage is unavailable? The oversized result guard falls back to truncating the result with a truncation marker (degraded but not broken).
- What happens when a mission is cancelled mid-tool-call? The in-progress tool call is interrupted if possible, and the trace records it as `cancelled`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a tool permission registry that maps tool name patterns to risk levels (`safe`, `confirm`, `admin`), evaluated before every tool call.
- **FR-002**: System MUST emit a typed UI approval event for `confirm`-level tool calls and await user resolution; the call MUST be denied if the user does not respond within a configurable timeout.
- **FR-003**: System MUST deny `admin`-level tool calls for non-internal missions and allow them for internal missions without a UI prompt.
- **FR-004**: System MUST support per-mission tool allowlists that restrict which tools a specific mission may invoke, enforced independently of the risk-level registry.
- **FR-005**: System MUST enforce four budget dimensions per mission: maximum tool-call count, maximum wall-clock duration, maximum cumulative tokens, and maximum per-tool-class duration.
- **FR-006**: System MUST cancel the mission and emit a typed budget-exceeded event when any budget limit is breached, including the specific limit that was exceeded.
- **FR-007**: System MUST produce a Mission Trace JSON for every completed or cancelled mission, containing mission ID, input hash, plan steps, tool-call records (name, arguments hash, duration, status, token usage), provider, and outcome.
- **FR-008**: System MUST hash all tool-call arguments by default in the trace, with a configurable allowlist of fields that may be recorded in cleartext.
- **FR-009**: System MUST maintain trace integrity under concurrent streaming events without data corruption or loss.
- **FR-010**: System MUST intercept tool results exceeding a configurable size threshold and replace them with compact artifact references before they enter model context.
- **FR-011**: System MUST provide a set of composable, individually disableable policy hooks shipped as framework defaults with sensible presets.
- **FR-012**: System MUST read tool risk metadata from the agent core when available, using the permission registry as an override when present.
- **FR-013**: System MUST provide a budget-degrade integration point so that budget enforcement can interact with the model client (e.g., switching to a lower-cost model when approaching token limits).

### Key Entities

- **Policy Hook**: A composable unit that intercepts and controls agent behavior at a specific point in the agent loop (before tool call, before run, etc.). Each hook can be enabled or disabled independently.
- **Permission Registry**: A mapping of tool name patterns to risk levels that determines whether a tool call is auto-approved, requires user confirmation, or is admin-only.
- **Mission Budget**: A set of numeric limits (tool calls, wall-clock, tokens, per-tool-class seconds) that bound a mission's resource consumption.
- **Mission Trace**: An append-only, structured record of everything that happened during a mission, suitable for replay and evaluation.
- **Artifact Reference**: A compact pointer to an externally stored large result, used when tool output exceeds the context-size threshold.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All tool calls are evaluated against the permission registry within 5 ms overhead per call, with no perceptible latency increase for `safe`-level tools.
- **SC-002**: Mission cancellation on budget breach completes within 100 ms of the breach detection, and the budget-exceeded event is emitted before any further tool calls execute.
- **SC-003**: A mission with 20+ tool calls produces a complete, schema-valid trace JSON that can be replayed end-to-end by an evaluation harness with 100% fidelity (all tool calls, arguments hashes, durations, and statuses match).
- **SC-004**: Oversized tool results (> threshold) are guarded with zero occurrences of raw large payloads entering model context, verified across 100 test missions.

## Assumptions

- The agent core provides a hook-based architecture where policy hooks can intercept tool calls, run lifecycle, and event emission.
- The kernel host (dependency #386) provides a mission object containing budget defaults, tool allowlists, and an internal-mission flag.
- Tool risk metadata is available from the agent core (dependency dart_agent_core#3) but the permission registry is the authoritative override.
- The trace schema is co-owned with the upstream architecture and will be finalized in a companion effort.
- Budget defaults are sourced from the mission object (playbook-provided), with framework-level sane fallbacks when not specified.
- The feature is framework-shipped (shipped as part of the Zuraffa agent framework), not application-specific.
- The trace recorder is coroutine-safe and does not introduce blocking under streaming event patterns.
- The evaluation harness and replay infrastructure exist separately and consume the trace JSON output.
- The oversized-result guard integrates with an external artifact storage mechanism (the specifics of which are outside this feature's scope).
- No PII is stored in traces by default; the arguments hash approach is the baseline, with explicit allowlisting as the opt-in path.
