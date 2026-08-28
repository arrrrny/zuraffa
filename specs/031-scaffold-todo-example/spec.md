# Feature Specification: Scaffold Todo Example via CLI with Full Test Suite

**Feature Branch**: `031-scaffold-todo-example`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "feat: scaffold todo example via CLI with full test suite"

**Issue**: [#225](https://github.com/arrrrny/zuraffa/issues/225)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate a Complete Todo Example App via CLI (Priority: P1)

A developer wants to scaffold a todo example application using only CLI commands, without writing any domain or data layer boilerplate manually. The generated app should include a `Todo` entity with all specified fields, full CRUD + watch use cases, and auto-generated tests for every use case.

**Why this priority**: This is the core deliverable — proving the CLI can produce a complete, working example app from scratch. Without this, the example app remains hand-maintained and untested.

**Independent Test**: Can be fully tested by running the `zfa` CLI commands to scaffold the todo entity and its use cases, then running `flutter test` to confirm all generated tests pass and `flutter analyze` reports zero errors/warnings.

**Acceptance Scenarios**:

1. **Given** a fresh project directory with the zuraffa CLI available, **When** the developer runs `zfa entity create` to define the Todo entity with fields `id`, `title`, `description`, `isCompleted`, `priority`, `tags`, `createdAt`, `completedAt`, **Then** the entity file is generated with the correct field types and structure.
2. **Given** the Todo entity exists, **When** the developer runs `zfa make` with `--preset=crud`, the methods `create`, `get`, `getList`, `update`, `delete`, `watch`, `watchList`, and `--test` enabled, **Then** all use case, repository, datasource, and test files are generated for every method.
3. **Given** all scaffolding is complete, **When** the developer runs `build_runner build`, **Then** the build succeeds with no errors and generates all required artifacts (zorphy comparisons, Hive type adapters, field indices).
4. **Given** the build succeeded, **When** the developer runs `flutter test`, **Then** all generated tests pass.
5. **Given** the tests pass, **When** the developer runs `flutter analyze`, **Then** the report shows 0 errors and 0 warnings.

**Independent Test**: Can be fully tested by running the scaffold commands on a clean directory and verifying the output compiles, tests pass, and analysis is clean.

---

### User Story 2 - Generated Structure Matches the Hand-Written Reference (Priority: P2)

A contributor wants to verify that the CLI-generated todo example produces the same flat layout structure under `example/lib/src/` as the manually written version from issue #219. The generated code should be a drop-in replacement for the hand-maintained version.

**Why this priority**: Structural parity ensures the CLI can replace manual maintenance without breaking existing examples or documentation that reference the todo app.

**Independent Test**: Can be tested by comparing the directory tree and file list of the CLI-generated output against the reference structure from #219.

**Acceptance Scenarios**:

1. **Given** the CLI-generated todo example, **When** a developer inspects the directory tree under `example/lib/src/`, **Then** the layout is flat (no deep nesting), matching the convention established in #219.
2. **Given** the generated files, **When** the developer checks the domain, data, and use case layers, **Then** no hand-written domain or data layer code is present — all architecture files are CLI-generated.

---

### User Story 3 - Hive Storage Indices Match the Entity Definition (Priority: P2)

A developer wants the Hive storage layer generated for the todo example to include correct field indices that match the entity definition, ensuring efficient queries and type-safe storage.

**Why this priority**: Mismatched indices cause runtime errors and silent data corruption. Correct indices are critical for the storage layer to function correctly.

**Independent Test**: Can be tested by inspecting the generated `hive_setup.g.yaml` file and verifying each field index matches the Todo entity's field definitions.

**Acceptance Scenarios**:

1. **Given** the generated todo example, **When** the developer inspects `hive_setup.g.yaml`, **Then** every field in the Todo entity has a corresponding index entry with the correct type.
2. **Given** the Hive setup file, **When** the developer compares the field count and types against the entity definition, **Then** there is a 1:1 match with no missing or extra fields.

---

### User Story 4 - Presentation Layer Remains Hand-Written (Priority: P3)

A developer understands that the CLI does not yet generate UI/presentation code and wants the todo example to include hand-written pages, controllers, and presenters as a working reference for how to build presentation on top of the generated architecture.

**Why this priority**: The presentation layer is explicitly out of scope for CLI generation but is needed for a runnable example app. This story documents the boundary.

**Independent Test**: Can be tested by verifying that hand-written presentation files exist under the example directory and that they import and use the generated architecture files correctly.

**Acceptance Scenarios**:

1. **Given** the scaffolded todo example, **When** the developer inspects the presentation layer, **Then** hand-written page, controller, and presenter files exist and compile without errors.
2. **Given** the hand-written presentation files, **When** the developer runs `flutter analyze`, **Then** no new errors or warnings are introduced by the presentation layer beyond what the generated code already produces.

---

### Edge Cases

- What happens when a required field type (e.g., `TodoPriority` enum) is not defined before scaffolding? The CLI should either auto-generate the enum or report a clear error.
- How does the system handle the `List<String>` field type for `tags`? The CLI must correctly infer the Hive type adapter and zorphy comparison logic for list-of-strings.
- What happens if the developer runs `zfa build` before completing all scaffold steps? The build should fail with a clear error message indicating missing artifacts.
- How does the system handle the `DateTime` fields (`createdAt`, `completedAt`) which may be nullable? The CLI must generate nullable-aware Hive adapters and comparison logic.
- What happens when the developer attempts to scaffold the todo app twice in the same directory? The CLI should detect existing files and either skip or overwrite with a warning, not silently corrupt.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CLI MUST generate a `Todo` entity with all specified fields (`id`, `title`, `description`, `isCompleted`, `priority`, `tags`, `createdAt`, `completedAt`) and their correct types.
- **FR-002**: The CLI MUST generate use case files for each of the seven methods: `create`, `get`, `getList`, `update`, `delete`, `watch`, `watchList`.
- **FR-003**: The CLI MUST generate a test file for every use case when `--test` is enabled, and the tests must be runnable and passing.
- **FR-004**: The CLI MUST generate a flat directory layout under `example/lib/src/` matching the structure established in the manual rewrite (issue #219).
- **FR-005**: The CLI MUST generate correct Hive field indices in `hive_setup.g.yaml` that match the entity definition with a 1:1 field mapping.
- **FR-006**: The CLI MUST support the `TodoPriority` enum type, including auto-generation of the enum definition and its zorphy comparison adapter.
- **FR-007**: The CLI MUST generate correct nullable-aware Hive adapters for `DateTime` fields and list-of-strings for the `tags` field.
- **FR-008**: The generated code MUST compile without errors when `build_runner build` is executed.

### Key Entities

- **Todo**: Represents a task item with fields: numeric identifier, title, description, completion status, priority level (enum), tags (list of strings), creation timestamp, and completion timestamp.
- **TodoPriority**: An enumeration of priority levels for todo items (exact values to be determined by the entity definition).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can scaffold a complete todo example app with all seven use cases and their tests using only `zfa` CLI commands, with zero hand-written domain or data layer code.
- **SC-002**: All generated tests pass (`flutter test` exits with code 0) on a clean scaffold.
- **SC-003**: Static analysis reports zero errors and zero warnings (`flutter analyze` exits with code 0).
- **SC-004**: The generated directory structure matches the reference layout from #219, with a flat layout under `example/lib/src/`.

## Assumptions

- The zuraffa CLI (`zfa`) is available and up-to-date from the `development` branch.
- The `example/` directory exists in the project root as the target for the todo app scaffold.
- The CLI does not yet generate presentation/UI code; the presentation layer will remain hand-written.
- The `TodoPriority` enum will be defined as part of the entity creation step (either auto-generated or manually defined before scaffolding).
- The Hive and zorphy code generation pipelines (`build_runner`) are functional and will produce the expected artifacts.
- The hand-written structure from issue #219 serves as the reference for directory layout parity.
- The `flutter` and `dart` SDKs are available in the development environment.
