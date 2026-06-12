# Feature Specification: Cache Adapter Command

**Feature Branch**: `009-cache-adapter-command`

**Created**: 2026-06-12

**Status**: Draft

**Input**: User description: "on cache plugin we should have a way to add adapter, when we create a new entity and if it will be stored in cache or local data source ,we must add it to hive registrar. cache plugin needs a command zfa cache adapter EntityName or enum that will create an adapter. it should look for each sub entity and create adapters for those as well."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatically generate Hive adapters for a new entity (Priority: P1)

A developer working on a Zuraffa project creates a new entity and needs to store it in a cache or local data source. Instead of manually writing Hive type adapters, updating the registrar, and registering each adapter, the developer runs a single `zfa cache adapter` command that handles the entire process automatically — including discovering sub-entities and generating adapters for them.

**Why this priority**: This is the core value proposition of the feature. Without this, developers must manually perform a tedious, error-prone process every time they add an entity that needs caching.

**Independent Test**: Can be fully tested by creating a new entity (e.g., `Product`) with sub-entities, running `zfa cache adapter Product`, and verifying that:
- Hive adapter classes are generated for the entity and all its sub-entities
- The Hive registrar file is updated with correct imports and `registerAdapter()` calls
- The project builds successfully after the command completes

**Acceptance Scenarios**:

1. **Given** a Zuraffa project with an existing entity `Product` that has sub-entities `Category` and `Variant`, **When** the developer runs `zfa cache adapter Product`, **Then** Hive adapters are generated for `Product`, `Category`, and `Variant`, and all are registered in the Hive registrar.

2. **Given** an entity that is an enum (e.g., `ProductStatus`), **When** the developer runs `zfa cache adapter ProductStatus`, **Then** a Hive adapter is generated for the enum and registered in the Hive registrar.

3. **Given** an entity that has no sub-entities, **When** the developer runs `zfa cache adapter SimpleEntity`, **Then** only one adapter is generated and registered.

4. **Given** the Hive registrar file already contains adapters from previous runs, **When** the developer runs the command for a new entity, **Then** the existing adapters are preserved and the new ones are appended.

---

### User Story 2 - Seamless integration with `zfa entity create` workflow (Priority: P2)

A developer follows the recommended Zuraffa workflow: create an entity with `zfa entity create`, then generate architecture with `zfa make`, and finally run `zfa build`. When the entity requires caching, the developer wants the `zfa cache adapter` command to fit naturally into this workflow without manual intervention.

**Why this priority**: This improves developer experience by making the cache adapter command a natural, discoverable step in the standard Zuraffa workflow.

**Independent Test**: Can be tested by executing the full workflow: `zfa entity create` → `zfa make Product --preset=crud --with=cache` → `zfa cache adapter Product` → `zfa build`, and verifying that the project compiles and the cache layer works correctly.

**Acceptance Scenarios**:

1. **Given** a newly created entity via `zfa entity create`, **When** the developer runs `zfa cache adapter` as part of the standard workflow, **Then** the command completes without errors and the entity is fully cacheable.

2. **Given** the project uses `zfa build` for code generation (build_runner), **When** `zfa cache adapter` completes, **Then** the developer can immediately run `zfa build` without any manual code edits.

---

### User Story 3 - Safe handling of existing registrations (Priority: P3)

A developer runs the cache adapter command multiple times or updates an entity after initial generation. The command should handle duplicate registrations gracefully and not break existing cache functionality.

**Why this priority**: This ensures robustness in day-to-day development when entities evolve and the command is re-run.

**Independent Test**: Can be tested by running the command twice for the same entity and verifying that the registrar file does not contain duplicate entries.

**Acceptance Scenarios**:

1. **Given** adapters were already generated for `Product`, **When** the developer runs `zfa cache adapter Product` again, **Then** no duplicate entries are added to the registrar.

2. **Given** sub-entities of `Product` already have adapters registered, **When** the developer adds a new sub-entity and re-runs the command, **Then** only the new sub-entity adapter is added, existing ones remain unchanged.

---

### Edge Cases

- What happens when the entity name provided does not exist in the project? The command should report a clear error and suggest available entities.
- How does the system handle circular sub-entity references? The command should detect and avoid infinite loops when discovering sub-entities.
- What happens when the entity has no sub-entities at all? Only the entity's own adapter should be generated.
- How does the system handle file system permissions issues when writing the registrar? The command should report the error with the specific file path and suggested fix.
- What happens when the registrar file does not yet exist? The command should create it with the proper structure.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a `zfa cache adapter <EntityName>` CLI command that accepts an entity name or enum name as argument.
- **FR-002**: The command MUST analyze the specified entity and discover all sub-entities (referenced types that are also entities) recursively.
- **FR-003**: The command MUST generate Hive type adapter classes for the entity and all discovered sub-entities.
- **FR-004**: The command MUST update the Hive registrar file by adding the necessary import statements for each entity's adapter.
- **FR-005**: The command MUST add `registerAdapter()` calls for each generated adapter in both the `HiveRegistrar` and `IsolatedHiveRegistrar` extensions in the registrar file.
- **FR-006**: The command MUST support enum types in addition to entity classes, generating appropriate enum adapters.
- **FR-007**: The command MUST detect and prevent duplicate registrations when run multiple times for the same entity.
- **FR-008**: The command MUST output clear error messages when the specified entity does not exist in the project.
- **FR-009**: The command MUST preserve all existing adapter registrations when adding new ones.
- **FR-010**: The command MUST handle circular references in entity graphs by detecting and breaking the cycle.

### Key Entities

- **Cache Plugin**: The Zuraffa CLI plugin responsible for cache and local data source management. Owns the adapter generation logic.
- **Hive Registrar**: A generated Dart file that enumerates all Hive type adapters and their registration calls. Contains both `HiveRegistrar` and `IsolatedHiveRegistrar` extension classes.
- **Entity**: A domain object in the Zuraffa project (created via `zfa entity create`). May reference other entities as sub-entities.
- **Type Adapter**: A generated class that serializes/deserializes an entity to/from binary format for Hive storage.
- **Sub-entity**: An entity that is referenced as a field type within another entity and must also have its own adapter.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can generate adapters for a new entity and all its sub-entities with a single `zfa cache adapter` command invocation.
- **SC-002**: The command completes in under 5 seconds for a typical entity with up to 10 sub-entities.
- **SC-003**: Zero manual edits are required to the Hive registrar file after running the command.
- **SC-004**: The project compiles and builds successfully immediately after running the command and `zfa build` without any human intervention.
- **SC-005**: Running the command twice for the same entity produces zero duplicate entries in the registrar file.
- **SC-006**: The command correctly discovers sub-entities up to at least 3 levels of nesting.

## Assumptions

- The project follows the standard Zuraffa v5 entity layout under `lib/src/domain/entities/`.
- Entities are created using `zfa entity create` before running the cache adapter command.
- The Hive registrar file follows the pattern shown in the Zuraffa cache plugin (containing both `HiveRegistrar` and `IsolatedHiveRegistrar` extensions).
- The cache plugin is already installed and configured in the project before using this command.
- Build artifacts are generated by running `zfa build` after the adapters are created.
- The command is idempotent — running it multiple times for the same entity should not break existing functionality.
- Sub-entities are discovered by analyzing field types of the entity model, not by runtime reflection.
