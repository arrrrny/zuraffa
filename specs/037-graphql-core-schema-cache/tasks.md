# Tasks: graphql_core — Schema Cache, Introspection & Type Mapping

**Input**: Design documents from `specs/037-graphql-core-schema-cache/`

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: Tasks marked with `[T]` are behavior-driving test tasks written FIRST
(TDD red), then made green by their pairing implementation task. Tests are
MANDATORY per the spec's SC-001..004.

**Organization**: Tasks are grouped by user story from `spec.md`. Each user
story can be implemented + tested independently and shipped as an MVP increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1=Pull & Cache (P1), US2=Diff (P2), US3=Type Mapping (P3)
- Exact file paths are in descriptions

## Phase 1: Setup (Shared Infrastructure)

- [x] T01 [P?] US1 Create `test/fixtures/graphql/` and generate
      `vendure_shop_introspection_v1.json` — a Vendure Shop API-shaped
      introspection response (~60 types: Product, ProductVariant, Order,
      OrderLine, Collection, Facet, FacetValue, Customer, Address, Money +
      DateTime custom scalars, Node interface, SearchResult/ErrorResult unions,
      SortOrder/CurrencyCode enums) with `queryType`/`mutationType` roots.
- [x] T02 [P?] US1 Create `test/fixtures/graphql/vendure_shop_introspection_v2.json`
      — v1 plus: `Collection` type removed (breaking), `Product.description`
      field removed (breaking), `ProductVariant.price` nullability changed
      `Money!` → `Money` (breaking), `Order.code` required field added
      (breaking), `Product.slug` optional field added (non-breaking),
      `CurrencyCode` enum value `XBT` added (non-breaking), `SortOrder` enum
      value `ASC`-adjacent value removed (breaking), `SearchResponse` type
      added (non-breaking).
- [x] T03 [P?] US1 Write `test/graphql/sdl_printer_test.dart` (RED) covering:
      object types render as `type Name { field: Type! }`, enums render
      `enum Name { VALUE }`, unions render `union Name = A | B`, interfaces
      render `interface Name { ... }`, root schema header renders
      `schema { query: Query }`, nullability/list wrappers render
      `[Product!]!` correctly.
- [x] T04 US1 GREEN: Implement `lib/src/graphql/sdl/sdl_printer.dart`. Passes T03.

## Phase 2: User Story 1 — Pull & Cache (P1, MVP)

- [x] T05 [T] US1 RED: Write `test/graphql/introspection_client_test.dart`:
  - happy path via injected transport returns parsed introspection `data`;
  - HTTP non-200 → `IntrospectionException` mentioning the status code;
  - endpoint unreachable (transport throws) → `IntrospectionException` with
    "unreachable"/cause message;
  - GraphQL `errors` in 200 response → `IntrospectionException` surfacing the
    first error `message` and `path` (specific field/type that failed);
  - response missing `__schema` → `IntrospectionException` naming the missing
    key and suggesting introspection may be disabled;
  - null `queryType` → `IntrospectionException` about missing query root.
- [x] T06 US1 GREEN: Implement
      `lib/src/graphql/introspection/introspection_client.dart`. Passes T05.
- [x] T07 [T] US1 RED: Write `test/graphql/schema_cache_037_test.dart`:
  - `pull(name, endpoint, transport: fixture)` writes
    `.zfa/graphql/<name>/<name>.schema.json` AND
    `.zfa/graphql/<name>/<name>.schema.graphql` AND compat copies
    `.zfa/graphql/<name>.schema.json` + `.zfa/graphql/<name>.schema.graphql`;
  - SDL content parses back as text containing `type Query`/`type Product`;
  - re-pull overwrites files with fresh data and rotates the previous JSON to
    `<name>.schema.prev.json`;
  - `load(name)` on missing name throws `SchemaCacheError` naming the expected
    file path (no null);
  - `load(name)` after `pull` returns a `CachedSchema` with a parsed
    `GqlSchema`;
  - cache dir auto-created when missing (missing-cache-dir edge case);
  - `loadPrevious(name)` returns null when no previous version exists;
  - no partial files written when the fetch fails (error first, write after
    validation).
- [x] T08 US1 GREEN: Rewrite `lib/src/graphql/cache/schema_cache.dart` around
      the per-name layout (legacy single-file API preserved). Passes T07.
- [x] T09 [T] US1 RED: Write `test/commands/graphql_pull_command_test.dart`:
  - spawns a loopback `HttpServer` serving the v1 fixture; runs
    `PullCommand` with `--endpoint=http://127.0.0.1:<port>/graphql
    --name=vendure --dir=<tmp>/.zfa/graphql`; asserts both artifacts exist and
    pull completes < 10s (SC-001);
  - server returning 500 → command prints a clear error, writes no files;
  - server returning GraphQL errors body → error names the failing part;
  - server unreachable (closed port) → clear error, exit code non-zero.
- [x] T10 US1 GREEN: Implement `lib/src/commands/graphql_pull_command.dart`
      and register under `GraphqlCommand` (subcommands list beside
      `introspect`). Passes T09.

## Phase 3: User Story 2 — Diff (P2)

- [x] T11 [T] US2 RED: Write `test/graphql/schema_diff_test.dart` against the
      committed v1/v2 fixtures (SC-002, 100% accuracy):
  - identical schemas → empty change list, `hasBreaking == false`;
  - removed type (`Collection`) reported as breaking `typeRemoved`;
  - removed field (`Product.description`) reported as breaking `fieldRemoved`
    with type+field names;
  - nullability change (`ProductVariant.price` `Money!` → `Money`) reported as
    breaking `nullabilityChanged` including old→new rendering;
  - added required field (`Order.code: String!`) reported as breaking
    `requiredFieldAdded`;
  - added optional field (`Product.slug: String`) reported as non-breaking
    `optionalFieldAdded`;
  - added enum value (`CurrencyCode.XBT`) reported as non-breaking
    `enumValueAdded`;
  - removed enum value (`SortOrder` value removed) reported as breaking
    `enumValueRemoved`;
  - added type (`SearchResponse`) reported as non-breaking `typeAdded`;
  - aggregate: diff(v1, v2) → exactly the 9 expected changes, 5 breaking +
    4 non-breaking; `hasBreaking == true`.
- [x] T12 US2 GREEN: Implement `lib/src/graphql/diff/schema_diff.dart`
      (change model + `SchemaDiffer.diff`). Passes T11.
- [x] T13 [T] US2 RED: Write `test/commands/graphql_diff_command_test.dart`:
  - pre-populate cache via `SchemaCache` (v1 then v2 pulls from fixtures) in a
    temp `.zfa/graphql`; run `DiffCommand` with `name=vendure --dir=<tmp>`;
    assert all 9 changes printed, breaking ones flagged, `exitCode == 1`
    (FR-004);
  - identical schemas cached → "no breaking changes" report, `exitCode == 0`;
  - `--old`/`--new` explicit file overrides work;
  - unknown name → actionable error listing available cached schemas,
    `exitCode` non-zero;
  - no previous version → actionable error suggesting a first pull,
    non-zero exit.
- [x] T14 US2 GREEN: Implement `lib/src/commands/graphql_diff_command.dart`,
      register under `GraphqlCommand`. Passes T13.

## Phase 4: User Story 3 — Type Mapping (P3)

- [x] T15 [T] US3 RED: Write `test/graphql/dart_type_namer_test.dart`:
  - fieldName: `snake_case` → `snakeCase`, `camelCase` preserved, `kebab-case`
    → `kebabCase`;
  - className: `product` → `Product`, `product_variant` → `ProductVariant`;
  - reserved words: field `class` → `_$class` (or equivalent documented
    escape), `int`, `new`, `default` handled; class named `int` → `Int$`;
  - pure-camel identifiers pass through unchanged.
- [x] T16 US3 GREEN: Implement
      `lib/src/graphql/mapping/dart_type_namer.dart`. Passes T15.
- [x] T17 [T] US3 RED: Extend `test/graphql/type_mapper_test.dart` (existing
      file — new group `spec 037`):
  - `ID` → `String`, `Int` → `int`, `Float` → `double`, `String` → `String`,
    `Boolean` → `bool` (FR-005 built-ins, all from parsed schema types);
  - `DateTime` scalar → `DateTime`;
  - nullable `String` → `String?`;
  - `[Type]!` → `List<Type>`; `[Type]` → `List<Type?>`; `[Type!]` →
    `List<Type>`;
  - custom scalar `Money` with scalarMap `{Money: int}` → `int` (FR-006
    override);
  - custom scalar without mapping → documented fallback `dynamic` (edge case:
    scalar not present in scalarMap);
  - scalarMap loaded from `.zfa.json` via
    `TypeMapper.fromZfaConfig(json)` reading `graphql.scalarMap`;
  - malformed scalarMap (non-map / non-string values) → clear error, not a
    silent fallback;
  - union representation: `sealed class SearchResult` with member subtypes for
    `SearchResult` union (FR-008);
  - interface representation: `abstract class Node` with declared fields
    (FR-008).
- [x] T18 US3 GREEN: Extend `lib/src/graphql/mapping/type_mapper.dart`
      (DateTime, scalarMap wiring, union/interface representations via
      `DartTypeNamer`). Passes T17.

## Phase 5: Export, Analyze, Verify

- [x] T19 [P?] US1 Export the new libraries from `lib/zuraffa.dart`
      (`introspection_client`, `sdl_printer`, `schema_diff`,
      `dart_type_namer`); keep existing exports untouched.
- [x] T20 Run `dart analyze` — zero errors, zero warnings (infos must match
      the pre-existing baseline count, no new lints from new files).
- [x] T21 Run full `dart test` (fast tier) — record ACTUAL pass/fail counts;
      flag any pre-existing unrelated failures against the master baseline.
- [x] T22 Record red evidence for every behavior under
      `specs/037-graphql-core-schema-cache/tdd/red/` and author
      `tdd/verification.md` mapping SC-001..004 to tests.

## Phase 6: TDD Red Evidence (per behavior — recorded AFTER red tests are first run)

Each behavior in `tdd/test-list.md` gets a `NN-*.md` evidence file quoting the
first-run failure output (compile error or failing expectation), per the
repo's established convention (see `specs/036-xray-visual-overlay/tdd/red/`).
