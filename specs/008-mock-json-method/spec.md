# Feature Specification: Mock JSON Data Method

**Feature Branch**: `008-mock-json-method`

**Created**: 2026-06-06

**Status**: Draft

**Input**: User description: "I like how our mock plugin works with heuristic data option, add a new method called json and it will still generate mock data but it write the data to json and use fromJson method of the entities. this will allow easily swap json files for fast prototyping without code change. make a clean convention of foldering mock json data as well"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Mock Data as JSON Files (Priority: P1)

A developer wants to generate mock entity data as standalone JSON files that can be loaded at runtime. Instead of hardcoded Dart object creation, the generated helper code reads JSON files from disk and deserializes them using the entity's `fromJson` method. This allows swapping JSON content without regenerating or modifying any Dart code.

**Why this priority**: Core feature — without JSON generation, no other part of the feature delivers value.

**Independent Test**: Can be fully tested by running a JSON mock generation command for a single entity, verifying that valid JSON files are created at the expected location, and confirming the generated Dart helper loads and deserializes them correctly via `fromJson`.

**Acceptance Scenarios**:

1. **Given** an entity `Product` with fields `id` (String), `name` (String), `price` (double), **When** the developer invokes the JSON mock generation method for `Product`, **Then** a JSON file containing mock `Product` data is created at the expected output location.

2. **Given** the generated JSON file for `Product`, **When** the generated Dart helper code loads it, **Then** it deserializes into a `List<Product>` using `Product.fromJson()` for each entry.

3. **Given** a changed JSON file (edited manually by the developer), **When** the application loads the mock data helper, **Then** it reflects the updated JSON content without any code regeneration.

4. **Given** an entity with nested entity relationships (e.g., `Order` contains `List<OrderItem>`), **When** JSON mock generation is invoked for the parent entity, **Then** JSON files are generated for both the parent and nested entities, with correct nesting in the JSON structure.

---

### User Story 2 - Clean Folder Convention for Mock JSON Data (Priority: P2)

A developer or team member knows exactly where to find mock JSON files for any entity and how to add or replace them. The folder structure follows a predictable, documented convention that mirrors the entity organization.

**Why this priority**: Without a clean convention, JSON files become scattered and unmanageable, negating the fast-prototyping benefit.

**Independent Test**: Can be tested by inspecting the output directory after generation and verifying the folder layout matches the documented convention for entities at various nesting levels and across multiple domains.

**Acceptance Scenarios**:

1. **Given** a generated mock JSON setup, **When** a developer navigates the output directory, **Then** mock JSON files are located in a dedicated, consistently named directory that is separate from generated Dart code.

2. **Given** entities in different domains (e.g., `Product` in `catalog`, `Order` in `checkout`), **When** JSON mock data is generated for both, **Then** each entity's JSON file resides in a path that clearly reflects its domain, preventing naming collisions.

3. **Given** the mock JSON folder convention, **When** a developer wants to add custom mock data for a new entity that doesn't yet have generated mocks, **Then** the expected file path and JSON structure are obvious from the convention alone.

---

### User Story 3 - Seamless Swap of JSON Files During Prototyping (Priority: P3)

A developer can replace a generated JSON file with handcrafted or API-exported data, and the application picks it up immediately on next load. No code changes, no regeneration, no restarts beyond normal hot reload.

**Why this priority**: This is the ultimate benefit of the feature — rapid iteration — but depends on P1 and P2 being in place first.

**Independent Test**: Can be tested by generating mock JSON for an entity, manually replacing the JSON file content with different data, and verifying the application loads the new data on next access.

**Acceptance Scenarios**:

1. **Given** generated mock JSON files for `Product`, **When** the developer replaces the JSON file with different product data (matching the same JSON structure), **Then** the application serves the replaced data on next load without any code regeneration.

2. **Given** a JSON file with additional fields not present in the entity definition, **When** the helper loads and deserializes it via `fromJson`, **Then** unknown fields are ignored gracefully and known fields are populated correctly.

3. **Given** a missing or corrupted JSON file, **When** the application attempts to load mock data, **Then** a clear, actionable error message indicates which file has the problem.

---

### Edge Cases

- What happens when an entity has fields with types that don't serialize cleanly to JSON (e.g., `DateTime`, custom value objects)? System must generate JSON that round-trips correctly through `fromJson`.
- What happens when regenerating JSON mock data while custom-edited JSON files already exist? The system must not overwrite user-edited files by default.
- What happens when the entity's field set changes after JSON files were generated? The system must detect mismatches and warn or offer regeneration.
- How does the system handle entities with enum fields? Enum values must be serialized as their JSON-compatible representation (typically string values) that `fromJson` expects.
- What happens with polymorphic/sealed entities that have multiple concrete subtypes? The JSON must include a discriminator field so `fromJson` can correctly instantiate the right subtype.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a JSON mock data generation method that creates valid JSON files containing mock data for a specified entity.
- **FR-002**: System MUST use the same field-type-based heuristic value generation as the existing mock data method to produce mock values for JSON output.
- **FR-003**: The generated Dart helper MUST deserialize JSON files using the entity's `fromJson` factory constructor.
- **FR-004**: System MUST place generated JSON files in a clean, predictable folder convention that keeps JSON data separate from generated Dart code.
- **FR-005**: The folder convention MUST group JSON files by domain to prevent naming collisions between entities with the same name in different domains.
- **FR-006**: System MUST recursively generate JSON files for nested entity types referenced by the primary entity.
- **FR-007**: System MUST NOT overwrite existing user-edited JSON files by default during regeneration; overwrite must require an explicit opt-in flag.
- **FR-008**: System MUST serialize enum values in a format compatible with the entity's `fromJson` deserialization.
- **FR-009**: System MUST handle `DateTime` and other non-primitive types with correct JSON serialization that round-trips through `fromJson`.
- **FR-010**: System MUST include a discriminator field in JSON output for polymorphic/sealed entity hierarchies.
- **FR-011**: System MUST generate a Dart helper file alongside the JSON that provides typed accessors (e.g., `Future<List<Product>> loadProducts()`) reading from the JSON files.
- **FR-012**: The generated Dart helper MUST produce clear error messages when a JSON file is missing, malformed, or contains data that fails `fromJson` deserialization.
- **FR-013**: System MUST generate JSON files with standard formatting (pretty-printed, consistent indentation) for human readability and manual editing.

### Key Entities *(include if feature involves data)*

- **Mock JSON Helper**: A generated Dart file providing typed async accessors that load and deserialize JSON mock data for a specific entity. Contains methods like `loadProducts()`, `loadSampleProduct()`, etc.
- **Mock JSON File**: A JSON file containing an array of mock entity objects, structured to match the entity's `fromJson` expected format. Located in the organized folder convention.
- **Mock JSON Folder Convention**: A directory structure under the output root (e.g., `data/mock_json/{domain}/`) that organizes JSON files by domain and entity, with a naming convention that mirrors entity snake_case names.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can generate JSON mock data for a new entity in under 10 seconds from command invocation to having readable JSON files on disk.
- **SC-002**: A developer can swap mock data by replacing a JSON file and see the change reflected in the application on the next data load, without any code regeneration steps.
- **SC-003**: Generated JSON files pass standard JSON validation (RFC 8259) on first generation with no syntax errors.
- **SC-004**: Round-trip integrity — mock data generated as JSON and then loaded through the generated helper produces the same number of entities with non-null field values matching the heuristic generation rules.
- **SC-005**: 100% of entities with standard field types (primitives, DateTime, enums, nested entities) produce valid JSON that deserializes successfully through `fromJson`.
- **SC-006**: Folder convention prevents naming collisions — two entities with the same name in different domains each have unique, non-conflicting JSON file paths.

## Assumptions

- Entities have `fromJson` factory constructors available (existing entities generated via `zfa entity create` already satisfy this).
- The existing heuristic value generation logic in the mock plugin can be adapted for JSON output without a full rewrite.
- JSON serialization of `DateTime` follows ISO 8601 format, consistent with Zorphy's default JSON codec.
- User-edited JSON files are detected by tracking a generation hash or by the default behavior of not overwriting existing files unless `--force` is used.
- The folder convention uses the entity's domain (derived from its location under `lib/src/domain/entities/`) as the organizing dimension.
- Default JSON file naming follows the pattern `{entity_snake}.mock.json` for the main data array.
