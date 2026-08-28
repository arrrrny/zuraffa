# Feature Specification: Agent Runtime Plugin

**Feature Branch**: `028-agent-runtime-plugin`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "agent: AgentRuntimePlugin + McpToolProvider SPI — in-proc kernel host over dart_agent_core. Build AgentRuntimePlugin plus an McpToolProvider SPI that hosts the agent kernel in-process over dart_agent_core. Originates from GitHub issue #386 (https://github.com/arrrrny/zuraffa/issues/386)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - In-Proc Agent Kernel Assembly (Priority: P1)

A Zuraffa app developer wants to assemble an agent kernel that composes all available tool sources — device packages (SPI providers), generated usecase tools, and remote MCP servers — into a single namespace and runs the agent loop in-process with zero IPC overhead.

**Why this priority**: This is the foundational capability. Without the kernel host assembling tools into a unified registry and running dart_agent_core's `StatefulAgent` loop in-process, no agent missions can execute at all.

**Independent Test**: Can be fully tested by registering one SPI provider and one generated usecase tool, starting the kernel, and verifying it executes a 3-tool mission with events streaming to a test observer.

**Acceptance Scenarios**:

1. **Given** an SPI provider and a generated usecase tool are registered, **When** the kernel is started with a mission, **Then** the agent loop executes the mission using tools from both sources and streams typed result events.
2. **Given** the kernel is assembled with a system prompt composition, **When** a mission runs, **Then** the system prompt includes the playbook text and all tool manifests (names, descriptions, schemas).
3. **Given** the kernel uses the in-proc serving path, **When** `McpManager` + `LocalMcpTransport` connect, **Then** tools are consumed with zero IPC overhead and no external server process is required.

---

### User Story 2 - McpToolProvider SPI for Device Packages (Priority: P1)

A device package developer (e.g., `dart_web_scraper`, `zikzak_inappwebview`) wants to self-describe its available tools to the agent kernel without the kernel knowing about the package's internals. The package registers an `McpToolProvider` with a namespace and returns its tool list at build time.

**Why this priority**: The SPI is the decoupling mechanism that allows third-party packages to contribute tools without coupling to zuraffa's internals. Without it, tool registration requires intimate knowledge of the kernel.

**Independent Test**: Can be fully tested by creating a test package that implements `McpToolProvider`, registering it via DI, and verifying the kernel discovers and exposes its tools.

**Acceptance Scenarios**:

1. **Given** a package implements `McpToolProvider` with a unique namespace, **When** it registers with the DI engine, **Then** the kernel discovers it and includes its tools in the flat registry.
2. **Given** multiple SPI providers register with distinct namespaces, **When** the kernel builds the tool registry, **Then** tools are namespaced to prevent collisions.
3. **Given** an SPI provider returns tools at build time, **When** `buildTools(McpToolContext)` is called, **Then** the returned tool list reflects the current state of the provider's capabilities.

---

### User Story 3 - Remote MCP Server Tool Merging (Priority: P2)

A Zuraffa app developer wants to merge tools from remote MCP servers (connected via SSE/Bearer with `dart_agent_core`'s `McpManager`) with in-proc SPI tools into a single tool namespace the agent sees, with collision-safe namespacing.

**Why this priority**: Remote tools extend the agent's reach beyond local packages but are not required for a minimal working kernel.

**Independent Test**: Can be fully tested by connecting a mock SSE server that exposes tools, verifying they appear in the registry alongside in-proc tools, and confirming namespace collision is prevented.

**Acceptance Scenarios**:

1. **Given** a remote MCP server is connected via `McpManager` with a unique namespace, **When** the kernel builds its registry, **Then** remote tools are merged with in-proc tools under their namespace.
2. **Given** a remote server and an SPI provider share the same namespace, **When** the kernel detects the collision, **Then** it reports the conflict and prevents silent tool overwriting.
3. **Given** a remote server is unreachable at mission time, **When** the kernel attempts to use its tools, **Then** the tool call fails gracefully with an error event rather than crashing the agent loop.

---

### User Story 4 - Mission Lifecycle and Session State (Priority: P2)

A Zuraffa app developer wants to run agent missions with a structured mission object (`missionId`, `spark`, `country/locale`, `budgets`, `toolAllowlist`, `riskTier`) and have session state persisted per-mission via `AgentState`/`FileStateStorage`.

**Why this priority**: Mission structure and session persistence ensure the agent operates within business constraints and can resume interrupted work.

**Independent Test**: Can be fully tested by submitting a mission with budget and tool-allowlist constraints, verifying the agent respects them, then resuming the mission and verifying state is restored.

**Acceptance Scenarios**:

1. **Given** a mission with a `toolAllowlist`, **When** the kernel executes, **Then** only tools in the allowlist are available to the agent.
2. **Given** a mission with budget constraints, **When** the agent approaches the budget limit, **Then** the kernel signals budget exhaustion via a typed event before exceeding it.
3. **Given** a mission session is interrupted, **When** the kernel resumes with the same `missionId`, **Then** session state is restored from `AgentState`/`FileStateStorage`.

---

### User Story 5 - AgentHook Registration for Policy Shell (Priority: P3)

A Zuraffa app developer wants to register ordered `AgentHook`s on the kernel for policy concerns (gating, budget enforcement, trace logging) that intercept mission execution at defined lifecycle points.

**Why this priority**: Policy hooks enable governance but are not required for basic agent operation.

**Independent Test**: Can be fully tested by registering a mock hook that logs calls and verifying it is invoked in the correct order during a mission.

**Acceptance Scenarios**:

1. **Given** ordered `AgentHook`s are registered on the kernel, **When** a mission executes, **Then** hooks are invoked in registration order at the defined lifecycle points.
2. **Given** a hook vetoes a mission (e.g., budget exceeded), **When** the hook returns a rejection, **Then** the kernel aborts the mission and emits a policy-rejection event.

---

### User Story 6 - Kernel Diagnostics (Priority: P3)

A Zuraffa app developer or operator wants to inspect the kernel's current state: which providers are registered, how many tools exist per namespace, and the health of connected remote servers.

**Why this priority**: Diagnostics aid debugging and monitoring but are not required for agent execution.

**Independent Test**: Can be fully tested by registering providers and connecting a remote server, then calling `kernel.status()` and verifying the returned data matches expectations.

**Acceptance Scenarios**:

1. **Given** providers and remote servers are registered, **When** `kernel.status()` is called, **Then** it returns a structured report with provider count, tool count per namespace, and remote server health status.
2. **Given** a remote server goes unhealthy, **When** `kernel.status()` is called, **Then** the health status reflects the failure without requiring the kernel to restart.

---

### Edge Cases

- What happens when an SPI provider's `buildTools` throws an exception during kernel assembly?
- How does the system handle a mission with an empty `toolAllowlist` (no tools available)?
- What happens when two SPI providers register the same namespace simultaneously?
- How does the kernel handle a remote MCP server that connects but returns no tools?
- What happens if `FallbackLLMClient` is unavailable (no LLM configured) when a mission starts?
- How does the system behave when a mission's `riskTier` exceeds the kernel's configured maximum?
- What happens when `FileStateStorage` is unavailable (e.g., read-only filesystem) and session state cannot be persisted?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an `McpToolProvider` SPI interface with a `namespace` identifier and a `buildTools(McpToolContext)` method that returns a list of MCP tools.
- **FR-002**: System MUST discover `McpToolProvider` implementations via DI/engine registration, allowing device packages to self-describe without the kernel knowing their internals.
- **FR-003**: System MUST assemble a flat `McpToolRegistry` from three tool sources: SPI providers (in-proc), generated usecase tools from `AgentPlugin`, and remote MCP servers via `dart_agent_core`'s `McpManager`.
- **FR-004**: System MUST expose the registry through an in-proc serving path so `McpManager` + `LocalMcpTransport` consume tools with zero IPC overhead.
- **FR-005**: System MUST implement an `AgentKernel` that delegates to `dart_agent_core`'s `StatefulAgent.runStream` for the agent loop, with tools bridged from the assembled registry.
- **FR-006**: System MUST compose the system prompt from playbook text and tool manifests (names, descriptions, schemas) before each mission.
- **FR-007**: System MUST wire `FallbackLLMClient` from `dart_agent_core` as the default LLM client for the kernel.
- **FR-008**: System MUST accept a `Mission` object (`missionId`, `spark`, `country/locale`, `budgets`, `toolAllowlist`, `riskTier`) as the kernel's single input and stream typed result events.
- **FR-009**: System MUST persist session state via `AgentState`/`FileStateStorage` on a per-mission basis, enabling mission resume after interruption.
- **FR-010**: System MUST support ordered `AgentHook` registration on the kernel for policy concerns (gating, budget, trace) that intercept mission execution at defined lifecycle points.
- **FR-011**: System MUST provide `kernel.status()` returning a structured report with registered providers, tool count per namespace, and remote server health.
- **FR-012**: System MUST detect namespace collisions between SPI providers, generated tools, and remote server tools, and prevent silent overwriting.
- **FR-013**: System MUST NOT duplicate agent-loop logic from `dart_agent_core` — the kernel must delegate entirely to `StatefulAgent`.

### Key Entities

- **McpToolProvider**: An SPI interface that device packages implement to declare their available tools under a namespace. Key attributes: `namespace` (String), `buildTools(McpToolContext)` method.
- **AgentRuntimePlugin**: The runtime module plugin that assembles the tool registry, wires the kernel, and manages the agent lifecycle.
- **McpToolRegistry**: A flat, collision-safe registry of all available MCP tools from all sources, keyed by namespace-prefixed tool names.
- **AgentKernel**: The thin orchestrator that bridges the tool registry to `dart_agent_core`'s `StatefulAgent` and manages mission execution.
- **Mission**: The kernel's structured input object containing `missionId`, `spark`, `country/locale`, `budgets`, `toolAllowlist`, and `riskTier`.
- **AgentHook**: An ordered callback interface for policy concerns (gating, budget, trace) that intercepts mission execution at lifecycle points.
- **AgentState**: Mission-scoped session state persisted via `FileStateStorage` for mission resume capability.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An example app can complete a 3-tool mission using one SPI provider and one generated usecase tool, streaming typed events to the UI, with zero agent-loop duplication from `dart_agent_core`.
- **SC-002**: Tools from a remote SSE server appear in the registry alongside in-proc SPI tools, with namespace collision prevented (verified by a dedicated test).
- **SC-003**: A test package implementing `McpToolProvider` can register with the DI engine and have its tools discovered by the kernel, verified by an integration test.
- **SC-004**: `kernel.status()` returns accurate provider count, tool count per namespace, and remote server health status, verified by a diagnostic test.

## Assumptions

- The kernel delegates the agent loop entirely to `dart_agent_core`'s `StatefulAgent` — no reimplemented loop logic.
- `dart_agent_core` provides `LocalMcpTransport`, `McpManager`, and `FallbackLLMClient` as external dependencies (PRs #1 and #2 in `dart_agent_core`).
- The in-proc MCP serving path (zuraffa PR #384) is available for zero-IPC tool consumption.
- `McpServerPlugin` concepts from zuraffa PR #374 provide the base for `AgentRuntimePlugin`.
- Device packages (`dart_web_scraper`, `zikzak_inappwebview`) implement the `McpToolProvider` SPI independently.
- Session persistence uses local filesystem (`FileStateStorage`) by default; remote persistence is out of scope for v1.
- Policy shell hooks (gating, budget, trace) are registered externally and consumed by the kernel as ordered `AgentHook`s.
- The `Mission` object structure is stable and agreed upon by the agent architecture team.
