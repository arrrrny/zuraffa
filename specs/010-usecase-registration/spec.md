# Feature Specification: Declarative UseCase Registration

**Feature Branch**: `010-usecase-registration`

**Created**: 2026-06-12

**Status**: Draft

**Input**: User description: "When I add usecases in a presenter and list them, I can compose presenter controller state and view. This works great initially, but later when I want to add a new usecase to an existing presenter or controller that already has multiple usecases, it becomes a nightmare. I should simply be able to add a new usecase without coordinated multi-point edits."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Add a Use Case to an Existing Presenter (Priority: P1)

A developer working on an existing feature needs to add a new capability (use case) to a Presenter that already has several registered use cases. Currently this requires modifying the Presenter class by adding a field declaration, a constructor registration call, and often corresponding changes in the Controller and State. The developer wants to make this a single-point change that automatically integrates with the existing Presenter wiring.

**Why this priority**: This is the most frequent operation and the core pain point — adding use cases to existing presenters is a daily task, and the multi-point edit overhead is the primary source of friction.

**Independent Test**: A developer can add one new use case reference to a Presenter and have it automatically registered, injected, and available in the controller without modifying any other file.

**Acceptance Scenarios**:

1. **Given** an existing Presenter with 3 registered use cases, **When** a developer adds a 4th use case via the intended mechanism, **Then** the use case is registered and lifecycle-managed without modifying the Presenter class body or constructor.
2. **Given** a newly added use case, **When** the Presenter is instantiated, **Then** the use case is available for invocation alongside all previously registered use cases.
3. **Given** a Presenter with dynamically registered use cases, **When** the Presenter is disposed, **Then** all use cases (including the newly added one) are properly cleaned up.

---

### User Story 2 - Add a Use Case to an Existing Controller (Priority: P1)

A developer working on a Controller (which directly orchestrates use cases without a Presenter) needs to add a new use case. Currently this requires field declarations and registration calls scattered across the Controller. The developer wants a simple, uniform way to declare that a Controller should have access to a new use case.

**Why this priority**: Controllers are the simpler orchestration layer and many developers use them directly. The fix must cover both Presenter and Controller paths.

**Independent Test**: A developer can declare a new use case on a Controller without touching the Controller's constructor or field declarations.

**Acceptance Scenarios**:

1. **Given** an existing Controller with multiple direct use cases, **When** a developer adds a new use case via the intended mechanism, **Then** the use case is automatically available in the Controller scope.
2. **Given** a Controller with the new use case, **When** the Controller's state is refreshed, **Then** the use case result can be consumed by the UI state.

---

### User Story 3 - Visual Clarity of Available Use Cases (Priority: P2)

A developer opening a Presenter or Controller file should be able to immediately see which use cases are available, without reading through the constructor body or searching for field declarations. The registration mechanism should make the set of use cases clearly visible at a glance.

**Why this priority**: This is about code readability and maintainability — reducing cognitive load when working with use-case-rich presenters and controllers.

**Independent Test**: A developer can open a Presenter file and identify all registered use cases within 5 seconds without scrolling through constructor code.

**Acceptance Scenarios**:

1. **Given** a Presenter with multiple use cases, **When** a developer reads the class declaration, **Then** the registered use cases are immediately apparent from the class structure.
2. **Given** a Controller with multiple use cases, **When** a developer reads the class declaration, **Then** the use cases are visually grouped and identifiable.

---

### User Story 4 - Remove a Use Case Without Side Effects (Priority: P3)

A developer needs to remove a use case from a Presenter or Controller (e.g., during refactoring or feature removal). This should be a single-point change that does not leave dangling references or break compilation.

**Why this priority**: Less frequent than adding, but equally painful when it happens.

**Independent Test**: A developer can remove a use case reference and have no compilation errors or runtime failures from orphaned references.

**Acceptance Scenarios**:

1. **Given** a Presenter with 4 use cases, **When** a developer removes one use case, **Then** the remaining 3 continue to work without modification.
2. **Given** a removed use case, **When** the application runs, **Then** no errors occur due to missing fields or references in the Presenter/Controller.

---

### Edge Cases

- What happens when a use case requires constructor parameters (e.g., a repository) that differ from the Presenter's existing dependencies?
- How does the system handle duplicate use case registration (same type registered twice)?
- What is the behavior when a use case depends on another use case's result?
- How does this interact with generated code (`zfa make` regenerating a Presenter) — are custom use case additions preserved?
- How does this impact testability — can individual use cases still be mocked independently in Presenter tests?

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Developers MUST be able to add a new use case to an existing Presenter or Controller by making a change in ONE location (not multiple coordinated edits).
- **FR-002**: The system MUST preserve all existing lifecycle management (dispose, cancel tokens, stream cleanup) for any newly registered use cases.
- **FR-003**: The registration mechanism MUST support both generated use cases (standard CRUD patterns) and custom use cases.
- **FR-004**: Use cases MUST be available to the Controller/View layer after declaration, without additional wiring.
- **FR-005**: The mechanism MUST integrate with the existing dependency injection (getIt) resolution pattern.
- **FR-006**: Removing a use case MUST be a single-point change that does not break compilation or leave orphaned code.
- **FR-007**: The mechanism MUST be exposed as CLI subcommands following the existing `zfa di <Name>` pattern:
  - `zfa presenter register <UseCaseName>` — register a use case in an existing Presenter
  - `zfa controller register <UseCaseName>` — register a use case in an existing Controller
  - `zfa state register <FieldName>` — register a field in an existing State class
  - `zfa register <UseCaseName> controller presenter state di` — batch register across all specified layers
- **FR-008**: The mechanism MUST use the same append-to-existing infrastructure (parsing existing source, injecting new fields and constructor registrations) already established by the datasource and mock plugins, rather than regenerating the whole file.
- **FR-009**: The mechanism MUST support both Presenter (complex orchestration) and Controller (simple orchestration) code paths uniformly.
- **FR-010**: The mechanism MUST be compatible with the existing test patterns — use cases must remain individually mockable in unit tests.

### Key Entities

- **UseCase**: A single business operation (e.g., `GetProductUseCase`). Has a `call` method and may depend on repositories or services.
- **Presenter**: An orchestration layer that coordinates multiple UseCases for complex business flows. Provides lifecycle management via `registerUseCase`.
- **Controller**: A simpler orchestration layer that calls UseCases directly and manages UI state. Also provides lifecycle management.
- **UseCase Registry**: The mechanism by which UseCases are declared and made available. Currently this is manual constructor registration; the feature aims to make this declarative.
- **Lifecycle Manager**: The disposal system that cleans up UseCases, subscriptions, and cancellation tokens when a Presenter/Controller is destroyed.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Adding a new use case to an existing Presenter requires exactly ONE file change (or one declaration addition) — no coordinated edits across multiple files or sections.
- **SC-002**: A developer can add a new use case and verify it works end-to-end (registered, invocable, disposable) in under 2 minutes.
- **SC-003**: The class declaration of a Presenter with 5+ use cases remains as readable as one with 1 use case — registration details do not clutter the file.
- **SC-004**: Removing a use case is a single-point change with zero compilation or runtime side effects.
- **SC-005**: Zero changes required to generated code files when adding or removing custom use cases.
- **SC-006**: All existing unit tests for Presenters and Controllers continue to pass without modification when a use case is added via the new mechanism.
- **SC-007**: No degradation in disposal behavior — all registered use cases still receive proper cleanup regardless of registration count.

## Assumptions

- The solution targets the Zuraffa v5 architecture and is built on top of the existing `Presenter` and `Controller` base classes.
- The existing `zfa di <Name>` command serves as the reference pattern for the new CLI subcommands.
- The append-to-existing infrastructure (`appendToExisting` config flag, source file parsing) already used by datasource and mock plugins will be reused for Presenter/Controller/State registration.
- Generated code (`zfa make` output) must not be overwritten when registering new use cases — only appended to.
- Developers are already familiar with the `registerUseCase` API — the new mechanism should feel like an evolution of the `zfa di` pattern.
- The primary consumer is a Flutter/Dart developer working within the Zuraffa framework.

## Extension Hooks

**Automatic Pre-Hook**: git
Executing: `/speckit-git-feature`
EXECUTE_COMMAND: speckit-git-feature
