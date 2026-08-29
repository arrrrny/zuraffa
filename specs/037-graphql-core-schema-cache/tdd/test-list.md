# TDD Test List — graphql_core Schema Cache, Introspection & Type Mapping

**Spec**: `specs/037-graphql-core-schema-cache/spec.md`
**Plan**: `specs/037-graphql-core-schema-cache/plan.md`
**Tasks**: `specs/037-graphql-core-schema-cache/tasks.md`

This list enumerates every behavior the implementation MUST satisfy, mapped to:
- The spec FR-NNN / SC-NNN it proves.
- The test file + test name that drives it.
- The implementation file + symbol that makes it green.

The red-green-refactor loop is run one behavior at a time. Every behavior has a
RED evidence file under `specs/037-graphql-core-schema-cache/tdd/red/` (created
when the test is first run before implementation). The final green state is
summarized in `tdd/verification.md`.

## Behaviors

### B01 — SDL printer renders object types, enums, unions, interfaces, roots

- **Spec**: FR-001 (SDL artifact), Key Entities
- **Test**: `test/graphql/sdl_printer_test.dart` — all tests in the group
- **Implementation**: `lib/src/graphql/sdl/sdl_printer.dart` — `SdlPrinter.print`

### B02 — Introspection fetch happy path via injectable transport

- **Spec**: FR-001 (fetch via introspection query)
- **Test**: `test/graphql/introspection_client_test.dart` — `fetch returns parsed data on success`
- **Implementation**: `lib/src/graphql/introspection/introspection_client.dart` — `IntrospectionClient.fetch`

### B03 — HTTP failure surfaces a detailed exception (no null-on-failure)

- **Spec**: FR-002, SC-004
- **Test**: `test/graphql/introspection_client_test.dart` — `non-200 status throws with status code`
- **Implementation**: `IntrospectionClient.fetch` → `IntrospectionException`

### B04 — Unreachable endpoint surfaces a clear error

- **Spec**: FR-002, SC-004 (network failure)
- **Test**: `test/graphql/introspection_client_test.dart` — `transport error throws unreachable error`
- **Implementation**: `IntrospectionClient.fetch` transport guard

### B05 — GraphQL errors surface with the failing field/type

- **Spec**: FR-002 (specific field/type that failed)
- **Test**: `test/graphql/introspection_client_test.dart` — `graphql errors surface message and path`
- **Implementation**: `IntrospectionException.graphqlErrors` + `path` plumbing

### B06 — Missing __schema / missing query root surface actionable errors

- **Spec**: FR-002 (partial introspection data), SC-004 (malformed schema)
- **Test**: `test/graphql/introspection_client_test.dart` — `missing __schema throws` / `null queryType throws`
- **Implementation**: `IntrospectionClient` validation guards

### B07 — Pull writes JSON + SDL artifacts in both layouts

- **Spec**: FR-001, SC-001, US-1 scenario 1
- **Test**: `test/graphql/schema_cache_037_test.dart` — `pull writes json + sdl in dir and flat layouts`
- **Implementation**: `lib/src/graphql/cache/schema_cache.dart` — `SchemaCache.pull`

### B08 — Re-pull overwrites fresh data and retains the previous version

- **Spec**: US-1 scenario 2, US-2 flow (pull → mutate → re-pull → diff)
- **Test**: `test/graphql/schema_cache_037_test.dart` — `re-pull overwrites and rotates prev`
- **Implementation**: `SchemaCache.pull` prev-rotation

### B09 — Missing cache name errors with the expected file path (no null)

- **Spec**: FR-002, SC-004 (missing cache dir)
- **Test**: `test/graphql/schema_cache_037_test.dart` — `load unknown name throws with path`
- **Implementation**: `SchemaCache.read` error path

### B10 — Cache dir auto-creation + no partial writes on failure

- **Spec**: US-1 scenario 3, SC-004
- **Test**: `test/graphql/schema_cache_037_test.dart` — `cache dir auto-created` / `no partial files when fetch fails`
- **Implementation**: `SchemaCache.pull` validate-then-write ordering

### B11 — `zfa graphql pull` end-to-end over loopback HTTP < 10s

- **Spec**: SC-001, FR-001
- **Test**: `test/commands/graphql_pull_command_test.dart` — `pull writes both artifacts within 10s`
- **Implementation**: `lib/src/commands/graphql_pull_command.dart` — `PullCommand.run`

### B12 — `zfa graphql pull` CLI error paths are loud, not silent

- **Spec**: FR-002, SC-004, US-1 scenarios 3–4
- **Test**: `test/commands/graphql_pull_command_test.dart` — `server 500`, `graphql errors body`, `unreachable endpoint` tests
- **Implementation**: `PullCommand` error handling + `exitCode`

### B13 — Diff: identical schemas → no changes, exit 0

- **Spec**: FR-003, FR-004, US-2 scenario 1
- **Test**: `test/graphql/schema_diff_test.dart` — `identical schemas produce no changes`
- **Implementation**: `lib/src/graphql/diff/schema_diff.dart` — `SchemaDiffer.diff`

### B14 — Diff detects removed type (breaking)

- **Spec**: FR-003, US-2 scenario 2
- **Test**: `test/graphql/schema_diff_test.dart` — `removed type reported breaking`
- **Implementation**: `SchemaDiffer._diffTypes`

### B15 — Diff detects removed field (breaking)

- **Spec**: FR-003
- **Test**: `test/graphql/schema_diff_test.dart` — `removed field reported breaking`
- **Implementation**: `SchemaDiffer._diffFields`

### B16 — Diff detects nullability change (breaking)

- **Spec**: FR-003, US-2 scenario 4
- **Test**: `test/graphql/schema_diff_test.dart` — `nullability change reported breaking`
- **Implementation**: `SchemaDiffer` type-rendering comparison

### B17 — Diff detects added required field (breaking)

- **Spec**: FR-003, US-2 scenario 3
- **Test**: `test/graphql/schema_diff_test.dart` — `added required field reported breaking`
- **Implementation**: `SchemaDiffer._diffFields`

### B18 — Diff detects added optional field (non-breaking)

- **Spec**: FR-003, US-2 scenario 5
- **Test**: `test/graphql/schema_diff_test.dart` — `added optional field reported breaking` → `non-breaking`
- **Implementation**: `SchemaDiffer._diffFields`

### B19 — Diff detects enum value added (non-breaking) / removed (breaking)

- **Spec**: FR-003, Edge Cases
- **Test**: `test/graphql/schema_diff_test.dart` — `enum value added non-breaking` / `enum value removed breaking`
- **Implementation**: `SchemaDiffer._diffEnums`

### B20 — Diff aggregate vs Vendure v1→v2 fixture: 100% accuracy

- **Spec**: SC-002
- **Test**: `test/graphql/schema_diff_test.dart` — `v1 to v2 fixture diff is exactly the 9 expected changes`
- **Implementation**: `SchemaDiffer.diff` full engine

### B21 — `zfa graphql diff` exit code 1 with breaking changes, 0 without

- **Spec**: FR-004
- **Test**: `test/commands/graphql_diff_command_test.dart` — `breaking diff exits 1` / `clean diff exits 0`
- **Implementation**: `lib/src/commands/graphql_diff_command.dart` — `DiffCommand.run`

### B22 — `zfa graphql diff` CLI error paths (unknown name, no previous)

- **Spec**: SC-004, FR-002
- **Test**: `test/commands/graphql_diff_command_test.dart` — `unknown name lists cached schemas` / `no previous version suggests pull`
- **Implementation**: `DiffCommand` error handling

### B23 — Naming: camelCase/PascalCase conventions

- **Spec**: FR-007
- **Test**: `test/graphql/dart_type_namer_test.dart` — `fieldName camelCases` / `className PascalCases`
- **Implementation**: `lib/src/graphql/mapping/dart_type_namer.dart` — `DartTypeNamer`

### B24 — Naming: reserved-word handling

- **Spec**: FR-007
- **Test**: `test/graphql/dart_type_namer_test.dart` — `reserved words escaped`
- **Implementation**: `DartTypeNamer` reserved-word table

### B25 — Type mapping: all built-in scalars + DateTime + nullable + lists

- **Spec**: FR-005, US-3 scenarios 1–5, SC-003
- **Test**: `test/graphql/type_mapper_test.dart` — `spec 037` group scalar/nullable/list tests
- **Implementation**: `lib/src/graphql/mapping/type_mapper.dart` — `TypeMapper.mapType`

### B26 — Type mapping: scalarMap overrides built-ins, loaded from `.zfa.json`

- **Spec**: FR-006, US-3 scenario 6, Edge Cases (malformed scalarMap)
- **Test**: `test/graphql/type_mapper_test.dart` — `scalarMap override` / `fromZfaConfig` / `malformed scalarMap errors` / `unmapped custom scalar fallback`
- **Implementation**: `TypeMapper` scalarMap resolution + `TypeMapper.fromZfaConfig`

### B27 — Union/interface → Dart sealed/abstract representations

- **Spec**: FR-008, US-3 scenario 7
- **Test**: `test/graphql/type_mapper_test.dart` — `union representation` / `interface representation`
- **Implementation**: `TypeMapper.unionRepresentation` / `TypeMapper.interfaceRepresentation`
