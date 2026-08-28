# Feature Specification: X-Ray Control Deck — @XRayMock Decorator & Synthetic Payload Injector

**Feature Branch**: `specs/034-xray-control-deck`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "[v6] Track 4.3 — X-Ray Control Deck: @XRayMock Decorator & Synthetic Payload Injector: Add the X-Ray Control Deck: an @XRayMock decorator and synthetic payload injector for v6. This feature originates from GitHub issue #185 (https://github.com/arrrrny/zuraffa/issues/185)."

## User Scenarios & Testing

### User Story 1 — Annotate a UseCase with Mock Payloads (Priority: P1)

As a developer, I want to annotate my UseCase classes with `@XRayMock` decorators so that synthetic test payloads are automatically registered for the X-Ray Control Deck, enabling rapid scenario testing without touching hardware.

**Why this priority**: The annotation is the foundational entry point. Without it, no mocks can be registered, and the entire Control Deck has nothing to display. This is the minimum viable slice.

**Independent Test**: Can be fully tested by adding `@XRayMock` annotations to a UseCase and verifying the generated code contains the corresponding mock entries. Delivers value by documenting which scenarios a UseCase supports.

**Acceptance Scenarios**:

1. **Given** a UseCase class exists, **When** the developer adds `@XRayMock(name: 'Valid Product A', payload: '123456789')`, **Then** the build system recognizes the annotation and registers the mock entry.
2. **Given** a UseCase with multiple `@XRayMock` annotations, **When** the build runs, **Then** all annotated entries are collected and available for Control Deck generation.
3. **Given** a `@XRayMock` annotation has an optional `type` field, **When** the build runs, **Then** the type/color metadata is preserved for downstream UI rendering (green for valid, red for error, default for unknown).

---

### User Story 2 — YAML-Based Scenario Definition (Priority: P1)

As a developer, I want to reference a YAML file via `@XRayMock.fromYaml('assets/mocks/barcodes.yaml')` so that test scenarios can be updated independently of code, enabling rapid iteration on test matrices.

**Why this priority**: YAML-based mocks are equally fundamental to the Control Deck. They allow non-developers and CI pipelines to adjust scenarios without code changes. Co-priority with Story 1 because both feed the same registry.

**Independent Test**: Can be fully tested by providing a YAML file with entries, annotating a UseCase with `@XRayMock.fromYaml(...)`, and verifying the parsed entries appear in the generated deck. Delivers value by decoupling scenario data from source code.

**Acceptance Scenarios**:

1. **Given** a YAML file with `{name, payload, type?}` entries, **When** a UseCase references it via `@XRayMock.fromYaml(...)`, **Then** all entries from the YAML are registered as mock payloads.
2. **Given** the YAML file is updated with new entries, **When** the build runs, **Then** the Control Deck reflects the updated entries without any code changes.
3. **Given** a YAML file with malformed entries, **When** the build runs, **Then** a clear error message identifies the problematic entry and its location.

---

### User Story 3 — Control Deck UI Activation (Priority: P1)

As a developer using X-Ray mode, I want a sliding Control Deck panel that appears when I trigger it, listing all registered mock scenarios as tappable buttons, so I can quickly inject payloads during runtime.

**Why this priority**: The UI is the user-facing surface that makes all registration work actionable. Without it, the mocks have no way to be triggered. P1 because the feature is not usable without the deck.

**Independent Test**: Can be fully tested by activating X-Ray mode and verifying the Control Deck slides up with the correct buttons from annotations + YAML. Delivers value by providing immediate visual feedback on available mocks.

**Acceptance Scenarios**:

1. **Given** X-Ray mode is active, **When** the developer triggers the Control Deck, **Then** a panel slides up from the bottom displaying all registered mock buttons.
2. **Given** the Control Deck is open, **When** the developer taps a mock button, **Then** the payload is injected directly into the UseCase, bypassing the hardware layer.
3. **Given** mock entries have type metadata, **When** the Control Deck renders, **Then** each button is color-coded: green for valid, red for error, and a neutral color for unknown/unspecified types.
4. **Given** the Control Deck is open, **When** the developer dismisses it, **Then** the panel slides down and the X-Ray overlay remains active.

---

### User Story 4 — Programmatic Mock Registration (Priority: P2)

As a developer, I want to register mock entries programmatically via `XRayControlDeck.registerEntries(...)` so that mocks can be dynamically added at runtime beyond what annotations and YAML provide.

**Why this priority**: This extends the registration surface beyond static annotations and YAML. It is valuable for runtime-generated scenarios (e.g., from a CI matrix) but not required for the core workflow.

**Independent Test**: Can be tested by calling `registerEntries` at runtime and verifying the new entries appear in the Control Deck. Delivers value for dynamic and advanced test orchestration.

**Acceptance Scenarios**:

1. **Given** the Control Deck is initialized, **When** `registerEntries(List<XRayMockEntry>)` is called with new entries, **Then** those entries immediately appear as buttons in the deck.
2. **Given** duplicate entries are registered (same name + payload), **When** the Control Deck renders, **Then** duplicates are deduplicated and shown once.

---

### User Story 5 — Release Build Exclusion (Priority: P2)

As a developer shipping a production build, I want all X-Ray Control Deck functionality and mock data to be completely excluded from release builds so that no test infrastructure leaks into the shipped product.

**Why this priority**: Security and build-size hygiene are critical but secondary to the feature working correctly in dev/profile builds. P2 because the feature is debug/profile only by nature.

**Independent Test**: Can be tested by building in release mode and verifying no X-Ray-related code, annotations, or UI elements exist in the output. Delivers value by guaranteeing zero production footprint.

**Acceptance Scenarios**:

1. **Given** the project is built in release mode, **When** the build completes, **Then** no X-Ray Control Deck code, mock entries, or UI overlays are present in the output.
2. **Given** `@XRayMock` annotations exist in source, **When** a release build runs, **Then** the annotations are stripped and no generated XRayDeck files are produced.

---

### User Story 6 — Golden Test for Generated Deck (Priority: P3)

As a developer, I want a golden test that verifies a UseCase with `@XRayMock` annotations produces the expected XRayDeck with correct buttons, so that build-time code generation is validated automatically.

**Why this priority**: Golden tests provide regression safety for generated code. P3 because the feature works without golden tests — they add confidence but are not user-facing.

**Independent Test**: Can be tested by running the golden test suite and verifying the generated XRayDeck matches the expected snapshot. Delivers value by catching regressions in code generation.

**Acceptance Scenarios**:

1. **Given** a UseCase with two `@XRayMock` annotations, **When** the golden test runs, **Then** the generated XRayDeck snapshot matches the expected output exactly.
2. **Given** a UseCase with a YAML reference, **When** the golden test runs, **Then** the generated XRayDeck includes entries from the YAML file in the snapshot.

---

### Edge Cases

- What happens when a UseCase has no `@XRayMock` annotations and no YAML reference? The Control Deck should show no buttons (empty state) or be hidden entirely.
- What happens when a YAML file referenced by `@XRayMock.fromYaml` is missing at build time? The build should fail with a clear, actionable error message indicating the missing file path.
- What happens when a `@XRayMock` payload is an empty string? The system should accept it as a valid mock (empty-payload testing) and display it normally in the deck.
- What happens when more than 50 mocks are registered? The Control Deck should remain scrollable and performant without visual lag.
- What happens when two annotations share the same name but different payloads? Both should be preserved; deduplication is by name+payload pair, not name alone.
- What happens when X-Ray mode is inactive? The Control Deck trigger and overlay should be completely invisible and non-interactive.

## Requirements

### Functional Requirements

- **FR-001**: System MUST support an `@XRayMock` annotation with `name` (required), `payload` (required), and optional `type`/color fields that can be applied to UseCase classes.
- **FR-002**: System MUST support `@XRayMock.fromYaml('path.yaml')` that reads mock scenarios from a YAML file containing `{name, payload, type?}` entries.
- **FR-003**: System MUST scan `@XRayMock` annotations and YAML references at build time and generate a `{ViewName}_XRayDeck.dart` file containing all registered mock entries.
- **FR-004**: System MUST provide a Control Deck UI panel that slides up from the bottom when X-Ray mode is active, displaying all mock entries as tappable buttons with color-coded type indicators.
- **FR-005**: Tapping a Control Deck button MUST inject the corresponding payload directly into the UseCase, bypassing the hardware layer entirely.
- **FR-006**: System MUST support programmatic mock registration via `XRayControlDeck.registerEntries(List<XRayMockEntry>)` for runtime-added scenarios.
- **FR-007**: System MUST exclude all X-Ray Control Deck functionality, annotations, and generated code from release builds.
- **FR-008**: Updating a YAML file and re-running the build MUST update the Control Deck without any manual UI code changes.

### Key Entities

- **XRayMockEntry**: A mock scenario definition with a name, payload string, and optional type/color metadata. Represents a single injectable test payload.
- **XRayControlDeck**: The runtime UI component that renders the sliding panel of mock buttons and orchestrates payload injection into UseCases.
- **YAML Mock File**: An external file (`*.yaml`) containing a list of `{name, payload, type?}` entries that define test scenarios without code changes.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A developer can annotate a UseCase with `@XRayMock`, run the build, and inject 20 different payloads into the Control Deck in under 5 seconds (matrix testing).
- **SC-002**: Updating a YAML mock file and re-running the build produces an updated Control Deck with zero manual UI edits required.
- **SC-003**: Release builds contain zero X-Ray-related code, annotations, or generated files, verified by build output inspection.
- **SC-004**: A golden test validates that annotated UseCases produce the expected generated XRayDeck with correct button entries and color coding.

## Assumptions

- Track 1.3 (DDA Foundation) is completed, providing the `@XRayMock` annotation scanning infrastructure that this feature builds upon.
- Track 4.1 (XRayScope) is completed, providing the X-Ray mode activation and overlay infrastructure that the Control Deck integrates with.
- The `zfa build` pipeline supports annotation scanning and code generation for custom annotations.
- YAML files follow a simple `{name, payload, type?}` schema and are stored under standard asset paths (e.g., `assets/mocks/`).
- The Control Deck is only relevant in debug and profile build modes; release builds strip all related code.
- Developers have an existing UseCase pattern in the project that the Control Deck can hook into for payload injection.
