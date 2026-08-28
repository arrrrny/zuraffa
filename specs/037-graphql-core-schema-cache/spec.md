# Feature Specification: graphql_core — Schema Cache, Introspection & Type Mapping

**Feature Branch**: `037-graphql-core-schema-cache`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "[v6] Track 3.1 — graphql_core: Schema Cache, Introspection & Type Mapping: This feature originates from GitHub issue #174 (https://github.com/arrrrny/zuraffa/issues/174). Implement graphql_core schema cache, introspection, and type mapping for v6."

## User Scenarios & Testing

### User Story 1 — Pull and Cache a GraphQL Schema (Priority: P1)

As a Zuraffa developer, I want to pull a remote GraphQL schema via introspection and have it cached locally so that I can generate type-safe code without re-fetching.

**Why this priority**: Schema acquisition is the entry point for all GraphQL workflows. Without it, no downstream code generation or diffing is possible.

**Independent Test**: Run `zfa graphql pull --endpoint=<url>` and verify that `.zfa/graphql/<name>.schema.json` and `.zfa/graphql/<name>.schema.graphql` are written. Can be tested with a committed Vendure Shop API introspection fixture (no network required).

**Acceptance Scenarios**:

1. **Given** a valid GraphQL endpoint URL, **When** `zfa graphql pull --endpoint=<url>` is executed, **Then** SDL and introspection JSON are written to `.zfa/graphql/<name>.schema.json` and `.zfa/graphql/<name>.schema.graphql`.
2. **Given** an existing cached schema in `.zfa/graphql/`, **When** `zfa graphql pull` is re-run against the same endpoint, **Then** the files are overwritten with fresh data.
3. **Given** an unreachable or invalid endpoint, **When** `zfa graphql pull` is executed, **Then** a clear error message is surfaced (not a null-on-failure) and no partial files are written.
4. **Given** an introspection query that returns partial data, **When** the response is processed, **Then** the error is surfaced with the specific fields or types that failed.

### User Story 2 — Diff a Schema for Breaking Changes (Priority: P2)

As a Zuraffa developer, I want to compare a newly pulled schema against the previously cached one to detect breaking and non-breaking changes before regenerating code.

**Why this priority**: Schema drift is the primary source of runtime errors in GraphQL code generation. Diffing catches regressions early.

**Independent Test**: Pull a schema, modify the fixture to introduce a removed type or changed nullability, re-pull, and run `zfa graphql diff <name>`. Verify exit codes: 0 for no breaking changes, 1 for breaking changes. Uses committed fixtures only.

**Acceptance Scenarios**:

1. **Given** two identical cached schemas, **When** `zfa graphql diff <name>` is executed, **Then** the command exits with code 0 and reports no changes.
2. **Given** a schema where a type was removed, **When** the diff is run, **Then** the command exits with code 1 and reports the removed type as a breaking change.
3. **Given** a schema where a required field was added, **When** the diff is run, **Then** the command exits with code 1 and reports the added required field as a breaking change.
4. **Given** a schema where a field's nullability changed, **When** the diff is run, **Then** the command exits with code 1 and reports the nullability change as a breaking change.
5. **Given** a schema where a non-required field was added, **When** the diff is run, **Then** the command exits with code 0 and reports the addition as a non-breaking change.

### User Story 3 — Map GraphQL Types to Dart Types (Priority: P3)

As a Zuraffa developer, I want the core to map GraphQL type references to Dart types, including nullability, lists, custom scalars, and union/interface kinds, so that generated repositories and models use correct Dart types.

**Why this priority**: Correct type mapping is essential for type safety but depends on the schema cache being in place first.

**Independent Test**: Provide a set of GraphQL type references (ID, Int, Float, String, Boolean, DateTime, custom scalars, nullable, list, non-null list) and verify the mapper produces the expected Dart types. Can be unit-tested against the committed Vendure fixture.

**Acceptance Scenarios**:

1. **Given** a GraphQL scalar type `ID`, **When** the type mapper processes it, **Then** the Dart type `String` is produced.
2. **Given** a GraphQL scalar type `Int`, **When** the type mapper processes it, **Then** the Dart type `int` is produced.
3. **Given** a GraphQL scalar type `Float`, **When** the type mapper processes it, **Then** the Dart type `double` is produced.
4. **Given** a GraphQL scalar type `String` (nullable), **When** the type mapper processes it, **Then** the Dart type `String?` is produced.
5. **Given** a GraphQL list type `[Type]!`, **When** the type mapper processes it, **Then** the Dart type `List<Type>` is produced.
6. **Given** a custom scalar defined in `.zfa.json` scalarMap (e.g., `Money → int`), **When** the type mapper processes it, **Then** the custom mapping overrides the built-in default.
7. **Given** a GraphQL union or interface type, **When** the type mapper processes it, **Then** a Dart abstract class or union representation is produced with all member types accessible.

### Edge Cases

- What happens when the introspection query returns a schema with circular type references (e.g., `User` has field `friends: [User]`)?
- How does the system handle a GraphQL endpoint that requires authentication headers during introspection?
- What happens when `.zfa.json` contains a malformed scalarMap entry?
- How does the diff behave when the schema introduces a new enum value (non-breaking) vs. removes an enum value (breaking)?
- What happens when the schema cache directory `.zfa/graphql/` does not exist yet?
- How does the system handle a schema that defines custom scalars not present in the scalarMap?

## Requirements

### Functional Requirements

- **FR-001**: System MUST fetch a GraphQL schema via introspection query from a user-provided endpoint URL and persist both SDL (`.schema.graphql`) and introspection JSON (`.schema.json`) under `.zfa/graphql/<name>/`.
- **FR-002**: System MUST surface introspection errors clearly (no null-on-failure) — including the specific field or type that failed to resolve.
- **FR-003**: System MUST detect breaking changes (removed type, removed field, changed nullability, added required field) and non-breaking changes (added optional field, added enum value) between two schema versions.
- **FR-004**: System MUST exit with code 0 when no breaking changes are detected and code 1 when breaking changes exist after a diff operation.
- **FR-005**: System MUST map all built-in GraphQL scalars (ID→String, Int→int, Float→double, String→String, Boolean→bool, DateTime→DateTime) and support nullable (`?`) and list (`List<T>`) Dart representations.
- **FR-006**: System MUST allow user-defined scalar mappings via `.zfa.json` scalarMap that override built-in defaults.
- **FR-007**: System MUST support naming conventions (camelCase, PascalCase) and reserved-word handling for type and field name generation.
- **FR-008**: System MUST handle GraphQL union and interface types in the schema model and produce appropriate Dart representations (abstract classes or sealed classes).

### Key Entities

- **GqlSchema**: Represents a parsed GraphQL schema — contains types, directives, query/mutation/subscription root types, and scalars. Persisted as `.schema.json`.
- **GqlTypeDef**: A single named type definition within the schema — includes kind (scalar, object, enum, input, interface, union), fields, and member types.
- **GqlTypeRef**: A type reference within a field or argument — includes name, nullability, list nesting, and whether it refers to a built-in or custom scalar.
- **SchemaCache**: Manages reading and writing of cached schema artifacts in `.zfa/graphql/` — ensures atomic writes and consistent state.

## Success Criteria

### Measurable Outcomes

- **SC-001**: `zfa graphql pull` correctly writes both SDL and introspection JSON for any valid public GraphQL endpoint within 10 seconds for schemas with fewer than 200 types.
- **SC-002**: `zfa graphql diff` correctly identifies all breaking changes (removed types, removed fields, nullability changes, added required fields) with 100% accuracy against the committed Vendure Shop API fixture.
- **SC-003**: The Dart type mapper produces correct Dart types for all built-in GraphQL scalars, nullable types, list types, and user-defined custom scalars — verified by unit tests against committed fixtures.
- **SC-004**: The schema cache subsystem handles error cases (network failure, malformed schema, missing cache directory) without silent failures — all errors surface as clear, actionable messages.

## Assumptions

- The target GraphQL endpoint supports standard introspection queries (no introspection disabled).
- The Vendure Shop API introspection fixture will be committed to the test suite for offline testing.
- `.zfa.json` is the canonical source for project-level configuration including scalarMap overrides.
- The feature is independent of other V6 runtime changes and can be built and tested in isolation.
- Naming conventions (camelCase, PascalCase) follow the existing Zuraffa namer patterns established in v5.
- Schema caching uses the existing `.zfa/` memory directory structure conventions.
- Authentication requirements for introspection are out of scope for the initial implementation (public endpoints only).
