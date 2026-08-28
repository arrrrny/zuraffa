# Feature Specification: V6 Twin-Turbo Moonshot Architecture

**Feature Branch**: `040-v6-twin-turbo-moonshot`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "V6 Twin-Turbo Moonshot Architecture: This feature originates from GitHub issue #163 (https://github.com/arrrrny/zuraffa/issues/163). Epic: V6 Twin-Turbo Moonshot architecture for AI-Native, Zero-Latency Flutter Infrastructure."

---

## Overview

This epic defines the Zuraffa v6 architecture vision: an **AI-Native, Zero-Latency Flutter Infrastructure**. It decomposes into eight shippable tracks spanning core runtime, state management, data storage, GraphQL, UI, observability, CLI tooling, and developer ergonomics. Each track is independently valuable but designed to integrate into a unified, high-performance framework for Flutter developers.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Runtime with Decorator-Driven Architecture (Priority: P1)

As a Flutter developer, I want a decorator-driven architecture that automatically wires datasources, repositories, and use cases so that I can focus on business logic without manual DI boilerplate.

**Why this priority**: The core runtime is the foundation all other tracks build on. Without it, no other component can function. Decorator-driven auto-DI eliminates the most tedious part of framework adoption.

**Independent Test**: Can be fully tested by applying `@Datasource`, `@Repository` decorators to classes and verifying automatic registration, async signal pipeline propagation, and telemetry emission — without any state, GraphQL, or UI plugin.

**Acceptance Scenarios**:

1. **Given** a developer defines a class annotated with `@Datasource`, **When** `zfa build` runs, **Then** the class is automatically registered in the DI container with correct lifecycle management.
2. **Given** a developer defines a class annotated with `@Repository` with an injected datasource, **When** the repository is resolved from DI, **Then** the datasource dependency is automatically injected.
3. **Given** an async signal is emitted from a datasource, **When** the signal propagates through the pipeline, **Then** all subscribed listeners receive the signal and telemetry records the propagation event.
4. **Given** the decorator-driven architecture is active, **When** a developer adds or removes a decorated class, **Then** the build system detects the change via AST analysis and regenerates only affected registrations.
5. **Given** a telemetry event occurs, **When** the unified telemetry mesh is active, **Then** the event is captured with timestamp, source, and payload without developer instrumentation.

---

### User Story 2 - TurboState: Fragmented Signal Slices with Dual-Layer Boundaries (Priority: P2)

As a Flutter developer, I want a state management system with fragmented signal slices that cleanly separates domain state from view state, so that my business logic is decoupled from UI concerns and cross-view synchronization happens automatically.

**Why this priority**: State management is the second-highest pain point in Flutter development. TurboState with domain/view separation and automated cache-binding delivers significant developer experience improvement once the core runtime exists.

**Independent Test**: Can be tested by creating state slices, binding them to widgets, changing domain state, and verifying that view state reflects the change only through the defined boundary — without GraphQL, X-Ray, or CLI dependencies.

**Acceptance Scenarios**:

1. **Given** a developer defines a `DomainState` fragment for product data, **When** the data changes, **Then** only the widgets consuming that specific fragment rebuild, not the entire widget tree.
2. **Given** a `DomainState` and a `ViewState` for the same feature, **When** domain state updates, **Then** the view state boundary maps domain changes to view-specific transformations automatically.
3. **Given** two separate views consuming the same `DomainState` fragment, **When** one view updates the fragment, **Then** the other view receives the update through automated cache-binding without manual synchronization.
4. **Given** a `ControlledWidget` with a `FragmentBuilder`, **When** the fragment data changes, **Then** only the fragment subtree rebuilds while the surrounding widget tree remains stable.
5. **Given** a developer uses the `@Cacheable` decorator on a state-producing method, **When** the method is called, **Then** results are cached and served from cache on subsequent calls within the defined TTL.

---

### User Story 3 - GraphQL Full-Stack Generation (Priority: P3)

As a Flutter developer, I want schema-to-full-stack generation from GraphQL definitions so that I can define my API contract once and get type-safe client code, resolver stubs, and integration glue automatically.

**Why this priority**: GraphQL generation accelerates backend-frontend alignment but depends on the core runtime and state layers being stable first.

**Independent Test**: Can be tested by providing a `.graphql` schema file and verifying that `zfa build` generates type-safe Dart models, query/mutation functions, and GraphQL client configuration — without runtime state or X-Ray dependencies.

**Acceptance Scenarios**:

1. **Given** a `.graphql` schema file defining a `Product` type and queries, **When** `zfa build` runs, **Then** type-safe Dart classes, query functions, and client configuration are generated.
2. **Given** a GraphQL schema with union types, **When** code generation runs, **Then** unions are mapped to Dart sealed classes with proper exhaustive pattern matching support.
3. **Given** a generated GraphQL client, **When** a query fails, **Then** structured error handling maps GraphQL errors to typed Dart exceptions with path and message information.
4. **Given** a GraphQL schema with subscriptions, **When** code generation runs, **Then** subscription support with WebSocket transport is generated and functional.
5. **Given** a generated schema cache, **When** `zfa build` runs without schema changes, **Then** regeneration is skipped and cached artifacts are reused.

---

### User Story 4 - X-Ray Observability and AI Agent Bridge (Priority: P3)

As a developer debugging a Flutter app or an AI agent inspecting app state, I want an X-Ray visual overlay and MCP bridge so that I can see widget trees, inject synthetic data, and execute actions on live app instances.

**Why this priority**: X-Ray provides unique debugging and AI-agent capabilities but requires the core runtime and view layers to be in place.

**Independent Test**: Can be tested by enabling X-Ray mode in a running app, verifying bounding box overlays appear on widgets, and confirming the MCP bridge exposes tree inspection and action execution endpoints.

**Acceptance Scenarios**:

1. **Given** an app running with X-Ray enabled, **When** the developer activates the overlay, **Then** bounding boxes with deterministic widget IDs appear over all registered widgets.
2. **Given** an X-Ray node with a deterministic ID, **When** the MCP bridge receives a tree inspection request, **Then** the full widget subtree is returned with widget types, states, and child relationships.
3. **Given** the `@XRayMock` decorator on a datasource, **When** a synthetic payload is injected via the X-Ray control deck, **Then** the datasource serves the injected payload instead of real data.
4. **Given** an AI agent connected via MCP bridge, **When** the agent sends an action execution request targeting a specific widget ID, **Then** the action is performed on the live app and the result is returned.
5. **Given** X-Ray widget IDs are deterministic, **When** the app hot-reloads, **Then** widget IDs remain stable for the same widget positions in the tree.

---

### User Story 5 - CLI Intelligence and Migration (Priority: P4)

As a developer upgrading from Zuraffa v5 or building complex features, I want an AST-aware CLI that performs smart regeneration and provides migration tooling so that builds are fast and the upgrade path from v5 is smooth.

**Why this priority**: CLI intelligence improves DX for all developers but is not a blocking dependency for any runtime feature.

**Independent Test**: Can be tested by running `zfa build` on a project with unchanged entities and verifying that only modified files are regenerated, and by running the migration tool on a v5 project and verifying output compiles.

**Acceptance Scenarios**:

1. **Given** a project where only one entity's datasource changed, **When** `zfa build` runs, **Then** only the affected datasource and its direct dependents are regenerated, not the entire project.
2. **Given** a v5 project with legacy generation artifacts, **When** the migration tool runs, **Then** a v6-compatible project structure is produced with all entity registrations, DI wiring, and build configuration updated.
3. **Given** the MCP Server 2.0 is active, **When** an AI agent sends a generation command, **Then** the CLI executes the command and returns structured results including generated file paths and any warnings.
4. **Given** a developer adds a new `@Route` decorator to a page, **When** `zfa build` runs, **Then** navigation routing is automatically registered without manual route table configuration.
5. **Given** the `@Retry` or `@RequiresAuth` middleware decorators are applied, **When** the decorated method is invoked, **Then** the middleware pipeline executes in the defined order before the core method.

---

### Edge Cases

- What happens when two tracks (e.g., TurboState and GraphQL) generate conflicting registrations for the same entity? **System MUST detect conflicts at build time and emit a structured error with both sources.**
- How does the system handle a v5 project with custom hand-written architecture that overlaps with generated code? **Migration tool MUST preserve hand-written files and generate alongside them, flagging conflicts for manual resolution.**
- What happens when X-Ray overlay is enabled in production builds? **System MUST strip X-Ray decorators and overlay code in release builds via tree-shaking configuration.**
- How does the async signal pipeline handle backpressure when a datasource emits faster than consumers process? **System MUST implement bounded buffers with configurable overflow behavior (drop-oldest, drop-newest, block).**
- What happens when the MCP bridge loses connection mid-action execution? **System MUST complete the action if already started and return partial results; pending actions are discarded with a timeout error.**
- How does the dual-layer state boundary handle circular dependencies between DomainState fragments? **Build system MUST detect circular fragment dependencies and reject them at compile time.**

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide decorator-driven automatic dependency injection for datasources, repositories, and use cases, eliminating manual DI container configuration.
- **FR-002**: System MUST implement an async signal pipeline that propagates reactive data changes through the system with configurable backpressure handling.
- **FR-003**: System MUST provide a unified telemetry mesh that captures framework events (signal propagation, DI resolution, state changes) with timestamps and structured payloads.
- **FR-004**: System MUST implement a dual-layer state boundary (DomainState vs ViewState) that cleanly separates business logic state from UI presentation state.
- **FR-005**: System MUST support fragmented signal slices where widgets rebuild only for the specific state fragments they consume, not the entire state tree.
- **FR-006**: System MUST generate type-safe GraphQL client code, sealed class mappings for union types, and subscription support from `.graphql` schema definitions.
- **FR-007**: System MUST provide X-Ray visual overlay with deterministic widget IDs, bounding boxes, and an MCP bridge for AI agent tree inspection and action execution.
- **FR-008**: System MUST perform AST-based smart regeneration that detects changed entities and regenerates only affected files, skipping unchanged artifacts.
- **FR-009**: System MUST provide migration tooling that converts v5 project structures to v6-compatible layouts while preserving hand-written files.
- **FR-010**: System MUST support additional decorators (`@Route`, `@Cacheable`, `@RequiresAuth`, `@Retry`, `@TrackEvent`) that auto-register behaviors during build.

### Key Entities

- **Entity**: Represents a domain model annotated for automatic DI registration, code generation, and state management. Key attributes: name, fields, decorators, associated repositories/datasources.
- **Signal**: A reactive data propagation unit flowing through the async pipeline. Key attributes: source, payload, timestamp, propagation path.
- **Fragment**: A named slice of application state consumed by specific widgets. Key attributes: name, domain/view layer, data type, binding targets.
- **Schema**: A GraphQL schema definition that drives full-stack code generation. Key attributes: types, queries, mutations, subscriptions, unions.
- **XRayNode**: A widget identified in the X-Ray overlay with a deterministic ID. Key attributes: widget ID, widget type, bounding box, child relationships, state snapshot.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new Zuraffa v6 project with 5 entities can be scaffolded from entity definition to compilable, runnable app using only `zfa` commands with zero hand-written DI, routing, or state wiring.
- **SC-002**: `zfa build` on a project with 50+ entities completes in under 10 seconds when no entities have changed (smart regeneration skips unchanged artifacts).
- **SC-003**: Widget rebuild scope after a state change is limited to consuming fragments only — verified by measuring rebuild counts with vs. without fragmented slices on a 100-widget tree.
- **SC-004**: The v5-to-v6 migration tool successfully converts at least 90% of v5-generated project structures to v6-compatible layouts without manual intervention (measured across the existing test suite of v5 projects).

---

## Assumptions

- Flutter developers using Zuraffa v6 have existing Flutter and Dart knowledge and are comfortable with annotation-driven frameworks.
- The core runtime (Track 1) will be completed before dependent tracks (State, GraphQL, X-Ray) begin integration.
- Existing v5 users will need a migration path but are not required to migrate immediately — v5 and v6 can coexist during transition.
- GraphQL integration targets standard GraphQL servers with introspection support; custom or non-standard GraphQL implementations are out of scope.
- The X-Ray visual overlay is intended for development and debug builds only; production builds must exclude X-Ray artifacts.
- The MCP Server 2.0 bridge targets local development scenarios; remote/cloud MCP connections are a future enhancement.
- AST-based smart regeneration uses Dart's analyzer for syntax-level change detection; semantic analysis beyond build-time resolution is out of scope for v6 initial release.
- Automated cache-binding for cross-view sync assumes a single-app context; cross-app or distributed state synchronization is deferred to the CRDT track.

---

## Sub-Epic Decomposition

This epic decomposes into the following child issues (tracked separately):

| Track | Issues | Focus Area |
|-------|--------|------------|
| 1 — Core Runtime | #170, #168, #172, #171 | Async Signal Pipeline, Telemetry, DDA, Auto-DI |
| 2 — State Plugin | #167, #166, #169, #173 | Fragmented Slices, Dual-Layer Boundary, Cache-Binding, ControlledWidget |
| 3 — Data & Storage | (via Track 2.3) | CRDT protocol (future) |
| 4 — GraphQL & GQL | #174, #178, #176, #175, #177 | Schema Cache, Generation, Union Mapping, File Gen, Runtime |
| 5 — View Plugin | #173 | ControlledWidget with FragmentBuilder |
| 6 — X-Ray & AI Bridge | #182, #181, #185, #184 | Widget IDs, Visual Overlay, Control Deck, MCP Bridge |
| 7 — CLI & MCP 2.0 | #180, #183, #179 | Smart Regeneration, MCP Server 2.0, Migration |
| 8 — Additional Decorators | #187, #188, #186 | @Route, @Cacheable, @RequiresAuth/@Retry/@TrackEvent |

---

## Source

- GitHub Issue: [#163 — V6 Twin-Turbo Moonshot Architecture](https://github.com/arrrrny/zuraffa/issues/163)
- Labels: `enhancement`, `v6`, `zuraffa_core`
