# Feature Specification: Simulation-Mode DI Binding

**Feature Branch**: `068-simulation-di-binding`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "[ROADMAP P1] Simulation-mode DI binding: the app boots end-to-end on certified mocks — request from issue #914 (https://github.com/arrrrny/zuraffa/issues/914). The mock-first demo dividend: every feature reaching complete(mocked) should be immediately demoable. Required: (1) generated DI registers mock datasources under a simulation flavor so flutter run --dart-define=SIMULATION=true boots the whole app on mocks with fixture data; (2) the simulation binding is generated (via zfa make --di / zfa mock create), not hand-wired, and the flavor switch is a single --dart-define; (3) every mocked-complete feature ships with shipping value before a single real adapter exists; (4) an isolation guard (landed with #832) asserts simulation mode never opens real sockets except through explicitly whitelisted lanes."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Boot the entire app on mocks with a single flag (Priority: P1)

A developer or product demonstrator wants to run the application in full simulation mode using only a build-time flag. Every datasource is backed by its generated mock with fixture data. No real network calls are made. The app boots, navigates through every mocked-complete feature, and demonstrates real UI flows with realistic (but synthetic) data — all without a single real adapter existing yet.

**Why this priority**: This is the core deliverable of the simulation mode. If the app cannot boot end-to-end on mocks, the "mock-first demo dividend" — shipping value before real adapters exist — is not achievable. This is the single action that proves the entire mock-first architecture works as a demoable product.

**Independent Test**: Can be fully tested by running the app with the simulation flag enabled and verifying: (a) the app launches without errors, (b) all mocked-complete features are navigable and display fixture data, (c) no real network calls are attempted (verified by the isolation guard).

**Acceptance Scenarios**:

1. **Given** the application has at least one feature in `complete(mocked)` state, **When** the developer builds and runs the app with the simulation flag enabled, **Then** the app boots successfully with all mock datasources active and fixture data displayed throughout the UI.

2. **Given** multiple features are in `complete(mocked)` state, **When** the developer navigates through each mocked-complete feature in simulation mode, **Then** every feature loads correctly with fixture data and no feature requires a real backend.

3. **Given** the simulation flag is not set, **When** the app boots, **Then** it uses the default (non-simulation) DI bindings and behaves as configured for normal operation.

---

### User Story 2 - Simulation bindings are generated, not hand-wired (Priority: P1)

A developer adds a new entity with mock datasources using `zfa make --di` and `zfa mock create`. The DI container automatically knows to bind the mock datasource for simulation mode. No manual DI registration, no hand-written service locator overrides, no glue code. The simulation flavor is a first-class output of the generation workflow.

**Why this priority**: If simulation bindings require manual wiring, every new entity adds maintenance burden and the bindings will inevitably drift from the actual mock implementations. Generated bindings ensure the simulation flavor stays in sync with the mock-first development workflow.

**Independent Test**: Can be tested by creating a new entity with `zfa make` and `zfa mock create`, then verifying the DI container includes a simulation binding for the new entity's datasource without any manual DI code.

**Acceptance Scenarios**:

1. **Given** a developer runs `zfa make <entity> --di` followed by `zfa mock create <entity>`, **When** the DI container is built for simulation mode, **Then** the entity's datasource is bound to its generated mock without any manual DI registration.

2. **Given** a new entity is added via the generation workflow, **When** the simulation flavor is activated, **Then** the new entity's mock datasource is automatically available alongside all previously registered mocks.

3. **Given** a generated simulation binding exists, **When** the developer inspects the DI registration code, **Then** the binding is clearly marked as simulation-generated and is distinguishable from hand-written bindings.

---

### User Story 3 - Isolation guard prevents real sockets in simulation mode (Priority: P1)

A developer runs the app in simulation mode. The isolation guard — a runtime check carried over from #832 — monitors all outgoing network activity and asserts that no real sockets are opened. If any real network call is attempted in simulation mode, the guard blocks it and produces a clear diagnostic. The only exceptions are explicitly whitelisted lanes (e.g., analytics endpoints that are allowed even in simulation).

**Why this priority**: Without the isolation guard, simulation mode is a hope rather than a guarantee. A mock datasource could accidentally delegate to a real API, or a hand-written component might bypass the mock layer entirely. The guard is the enforcement mechanism that makes "simulation means no real sockets" a verifiable fact.

**Independent Test**: Can be tested by running the app in simulation mode with a known real socket attempt (e.g., a component that makes a real HTTP call) and verifying the guard blocks it and reports the violation.

**Acceptance Scenarios**:

1. **Given** the app is running in simulation mode, **When** any component attempts to open a real network socket, **Then** the isolation guard blocks the connection and logs a clear violation message identifying the source.

2. **Given** the app is running in simulation mode, **When** a whitelisted lane (e.g., analytics) makes a network call, **Then** the isolation guard permits the call and logs it as an approved exception.

3. **Given** the app is running in normal (non-simulation) mode, **When** any network call is made, **Then** the isolation guard is inactive and does not interfere.

---

### Edge Cases

- What happens when the app has zero features in `complete(mocked)` state? The simulation mode boots but shows only scaffolded/placeholder screens. The developer is warned that no mocked features are available for demo.
- What happens when a real adapter is partially implemented alongside mocks? Simulation mode must exclusively use mocks; the presence of a real adapter must not interfere with the simulation flavor bindings.
- What happens when the simulation flag is set but the mock data files (fixtures) are missing or corrupted? The app must fail to boot with a clear error message identifying which entity's fixtures are missing, not a silent crash or blank screens.
- What happens when the isolation guard whitelist is empty? All network calls are blocked in simulation mode; this is the safest default.
- What happens when the simulation flag conflicts with other build-time flags (e.g., a real-backend flag)? The system must resolve conflicts explicitly, with simulation mode taking precedence or producing a clear conflict error — never silently falling through to real network calls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single build-time flag that activates simulation mode across the entire application.
- **FR-002**: System MUST generate simulation DI bindings as part of the standard `zfa make --di` and `zfa mock create` workflow, requiring no manual DI registration.
- **FR-003**: System MUST register all mock datasources under the simulation flavor so that every `complete(mocked)` feature is available with fixture data when simulation mode is active.
- **FR-004**: System MUST NOT require any real adapter to exist for the simulation mode to function; the app must be fully demonstrable with mocks alone.
- **FR-005**: System MUST enforce an isolation guard that asserts no real network sockets are opened during simulation mode.
- **FR-006**: System MUST support a whitelist of explicitly approved network lanes that are permitted in simulation mode (e.g., analytics).
- **FR-007**: System MUST block any non-whitelisted network attempt in simulation mode and produce a clear diagnostic identifying the source.
- **FR-008**: System MUST produce no-op or harmless behavior when the isolation guard is active in normal (non-simulation) mode.
- **FR-009**: System MUST fail to boot with a clear error message if fixture data is missing or corrupt when simulation mode is activated.
- **FR-010**: System MUST warn the developer when simulation mode boots with zero `complete(mocked)` features available.
- **FR-011**: System MUST clearly distinguish simulation-generated DI bindings from hand-written bindings in the codebase (e.g., via generated markers or file location).
- **FR-012**: System MUST resolve conflicts between simulation mode and other build-time flags explicitly — simulation mode must either take precedence or produce a conflict error, never silently fall through.
- **FR-013**: System MUST support the simulation flavor as a first-class concept in the DI container, not a runtime monkey-patch or environment hack.

### Key Entities

- **Simulation Flag**: The single build-time parameter that activates simulation mode across the entire application, switching all DI bindings to their mock variants.
- **Simulation DI Binding**: A generated DI registration that maps each entity's datasource interface to its mock implementation with fixture data. Created automatically by the generation workflow.
- **Isolation Guard**: A runtime monitor that intercepts all outgoing network activity and asserts that no real sockets are opened in simulation mode, except for explicitly whitelisted lanes.
- **Whitelisted Lane**: An explicitly approved network path that is permitted to bypass the isolation guard in simulation mode (e.g., analytics, crash reporting).
- **Mock Datasource**: A generated data source implementation that serves fixture data for a specific entity, used exclusively in simulation mode.
- **Fixture Data**: Pre-generated, realistic test data that populates the UI in simulation mode, providing shipping-quality demo content.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An application with any number of `complete(mocked)` features boots to a fully navigable state in simulation mode within 2 seconds of launch on standard development hardware.
- **SC-002**: Zero real network sockets are opened during a complete simulation mode session (verified by the isolation guard with zero violations).
- **SC-003**: Adding a new entity with `zfa make --di` and `zfa mock create` automatically includes its mock in the simulation DI — zero manual steps required.
- **SC-004**: The simulation flag is a single parameter; no additional configuration, flags, or manual wiring is needed to activate simulation mode.
- **SC-005**: Missing or corrupt fixture data produces a boot-time error with a specific message identifying the affected entity, not a silent failure or blank screen.
- **SC-006**: All simulation-generated DI bindings are clearly distinguishable from hand-written bindings in the generated codebase.

## Assumptions

- The application framework supports build-time flags passed as compile-time defines (e.g., `--dart-define` in Flutter).
- The `zfa make --di` and `zfa mock create` commands already exist and can be extended to emit simulation bindings as part of their output.
- The isolation guard infrastructure from #832 has been landed and is available for reuse in this feature.
- Mock datasources follow a consistent generated interface that allows the DI container to swap them in without runtime type negotiation.
- Fixture data is generated or provided per-entity during the `zfa mock create` step and stored in a predictable location.
- The simulation flavor is a compile-time concept, not a runtime toggle; switching between simulation and real modes requires a rebuild.
- The whitelist for isolation guard exceptions is configurable via a project-level configuration file.
- The simulation mode is intended for development, demonstration, and testing — it is not a production deployment mode.
