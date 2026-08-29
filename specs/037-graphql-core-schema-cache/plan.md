# Implementation Plan: graphql_core — Schema Cache, Introspection & Type Mapping

**Branch**: `037-graphql-core-schema-cache` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/037-graphql-core-schema-cache/spec.md`

## Summary

This feature completes the v6 graphql_core track (issue #174): pulling a remote
GraphQL schema via introspection and caching it locally, diffing two schema
versions for breaking changes with proper exit codes, and mapping GraphQL types
to Dart types with nullability, lists, custom scalars, naming conventions, and
union/interface representations.

The repo already has a graphql foundation (`lib/src/graphql/` — types, schema
parser, introspection service, a stub `SchemaCache`, a partial `TypeMapper`, the
`zfa graphql introspect` command). This feature closes the gaps the spec calls
out: the cache fetch path is `UnimplementedError`, the cache layout is a single
anonymous `schema.json` (not the per-name `.zfa/graphql/<name>/` layout), no SDL
is ever written, nothing diffs schemas, the introspection service returns `null`
on failure (spec FR-002 forbids null-on-failure), and the type mapper has no
`DateTime`, no `.zfa.json` `scalarMap` wiring, no reserved-word handling, and no
union/interface Dart representation.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); toolchain used for this
work: Dart 3.13.2 (stable) on linux_x64. Pure Dart — no Flutter imports under
`lib/` (repo hard rule, regression test
`test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`).

**Primary Dependencies**: `http` (introspection POST — already a direct dep and
already used by `GraphQLIntrospectionService`), `path`, `analyzer`/`code_builder`
(not needed here — this feature is hand-rolled, no new dependencies). Zero new
packages: the diff engine, SDL printer, and type mapper are pure Dart over the
existing `GqlSchema`/`GqlTypeDef` model in `lib/src/graphql/graphql_schema.dart`.

**Existing subsystems (relevant)**:

- `lib/src/graphql/graphql_schema.dart` — `GqlSchema`, `GqlTypeDef`, `GqlTypeRef`,
  `GqlField`, `GqlEnumValue`: the introspection JSON model. Diffing will operate
  on this model.
- `lib/src/graphql/schema/schema_parser.dart` — `SchemaParser.parse` →
  `GraphQLSchema` (typed AST used by `TypeMapper`).
- `lib/src/graphql/cache/schema_cache.dart` — existing stub `SchemaCache`
  (single-file, no fetch, no SDL). This feature rewrites it around a per-name
  cache layout while keeping the legacy `load`/`save`/`hasCache` API working for
  the existing tests (`test/graphql/schema_cache_test.dart`).
- `lib/src/graphql/graphql_introspection_service.dart` —
  `GraphQLIntrospectionService.introspect` returns `null` on every failure.
  FR-002 forbids null-on-failure; we add a throwing API
  (`fetchIntrospectionResult`) with detailed, field/type-specific errors and
  keep the legacy nullable method delegating to it (no behavior break for
  `zfa graphql introspect`).
- `lib/src/graphql/mapping/type_mapper.dart` — `TypeMapper` with
  `customScalars`/`typeOverrides` constructor maps. Extended in place.
- `lib/src/commands/graphql_command.dart` + `graphql_introspect_command.dart` —
  the plugin command `zfa graphql` with `introspect` subcommand. `pull` and
  `diff` register as sibling subcommands of the same command.
- `lib/src/config/zfa_config.dart` — `.zfa.json` loading. The graphql section
  convention already exists (`graphql.errorMapping` in
  `lib/src/graphql/codegen/error_mapping_config.dart`), so `graphql.scalarMap`
  follows the same shape.

**Cache layout decision (spec ambiguity resolved)**: FR-001 says artifacts live
"under `.zfa/graphql/<name>/`" while US-1's acceptance scenario and Independent
Test name the files `.zfa/graphql/<name>.schema.json` and
`.zfa/graphql/<name>.schema.graphql`. To satisfy both readings the cache writes
the canonical pair into a per-name directory
`.zfa/graphql/<name>/<name>.schema.json` + `<name>.schema.graphql` **and** flat
compat copies `.zfa/graphql/<name>.schema.json` + `<name>.schema.graphql`.
Readers (`read`, diff) accept either location. The previous version of a
schema is retained as `<name>.schema.prev.json` so `zfa graphql diff <name>` can
compare the freshly pulled schema against the one it replaced (US-2's flow:
pull → mutate → re-pull → diff).

**Exit codes**: `zfa graphql diff` sets the top-level `exitCode` (1 when
breaking changes exist, 0 otherwise) instead of calling `exit()` so the command
stays testable in-process (pattern: `test/commands/*`).

**Testing**: `package:test`, fast tier (`dart test` — `exclude_tags: slow`).
Offline only: HTTP interactions use a loopback `HttpServer` bound in the test
itself; schema fixtures are committed JSON. New tests live in
`test/graphql/` (core) and `test/commands/` (CLI).

**Target Platform**: Pure-Dart VM (the CLI).

**Performance Goals**: SC-001 — `zfa graphql pull` writes both artifacts within
10s for <200-type schemas. The pull path is one HTTP round-trip + one
`SchemaParser.parse` + two file writes; for the committed Vendure fixture
(~60 types) this is well under 1s, which the test asserts with a wall-clock
budget.

**Scale/Scope**: ~6 new/rewritten lib files, ~7 new test files, 2 committed
fixtures (Vendure Shop API introspection v1 + v2-with-breaking-changes), 2 new
CLI subcommands, 1 export barrel update.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The Zuraffa constitution (`.specify/memory/constitution.md`) is still in
template form; the default gates apply, matching prior specs (036):

1. **Library-First**: All new logic lives in libraries under
   `lib/src/graphql/` (cache, diff, sdl, mapping) exported through
   `lib/zuraffa.dart`; commands under `lib/src/commands/` are thin wrappers.
2. **CLI Interface**: Two new subcommands `zfa graphql pull` /
   `zfa graphql diff` extend the existing `zfa graphql` plugin command.
3. **Test-First (NON-NEGOTIABLE)**: Every behavior in `tdd/test-list.md` has a
   failing test BEFORE its implementation. Red evidence recorded under
   `tdd/red/` and cited in `tdd/verification.md`.
4. **Integration Testing**: CLI-level tests exercise the real command objects
   (pull → files on disk; diff → exit code), not just the libraries.
5. **Simplicity**: Zero new dependencies; hand-rolled diff/SDL printer over the
   existing model. No reflection.

All gates pass at design time.

## Project Structure

### Documentation (this feature)

```text
specs/037-graphql-core-schema-cache/
├── spec.md              (input — already exists)
├── plan.md              (this file)
├── tasks.md             (MVP-first task list)
└── tdd/
    ├── test-list.md     (behaviors + tests + implementations)
    ├── red/             (red evidence per behavior)
    └── verification.md  (green state + SC mapping)
```

### Source code

```text
lib/src/graphql/
├── cache/
│   └── schema_cache.dart        (REWRITTEN — per-name layout, prev-version
│                                 retention, SDL + JSON writes, atomic write,
│                                 detailed errors; legacy API preserved)
├── introspection/
│   └── introspection_client.dart (NEW — throwing introspection fetch with
│                                 per-field/type error detail + injectable
│                                 transport for tests)
├── diff/
│   └── schema_diff.dart         (NEW — breaking/non-breaking change model +
│                                 SchemaDiffer)
├── sdl/
│   └── sdl_printer.dart         (NEW — GqlSchema → SDL document string)
└── mapping/
    ├── type_mapper.dart         (EXTENDED — DateTime, scalarMap from .zfa.json,
    │                             reserved words, camelCase/PascalCase naming,
    │                             union/interface Dart representation)
    └── dart_type_namer.dart     (NEW — naming conventions + reserved words)

lib/src/commands/
├── graphql_pull_command.dart    (NEW — `zfa graphql pull`)
└── graphql_diff_command.dart    (NEW — `zfa graphql diff`, exitCode 0/1)

lib/src/commands/graphql_command.dart  (EXTENDED — register pull + diff)

lib/zuraffa.dart                 (EXTENDED — export new libraries)
```

### Fixtures

```text
test/fixtures/graphql/
├── vendure_shop_introspection_v1.json  (NEW — Vendure Shop API-shaped
│                                         introspection result, ~60 types)
└── vendure_shop_introspection_v2.json  (NEW — v1 + removed type, removed
                                          field, nullability change, added
                                          required field, added optional
                                          field, added/removed enum values)
```

The fixture is a faithful subset of the Vendure Shop API surface (Product,
ProductVariant, Order, OrderLine, Collection, Facet, FacetValue, Customer,
Address, Money/DateTime scalars, `Node` interface, `SearchResult` union,
`ErrorResult` unions, `SortOrder`/`CurrencyCode` enums) expressed in the exact
introspection-response JSON shape the real endpoint returns, so `SchemaParser`
consumes it as-is.

## Goals & Strategy

### Primary goal

`zfa graphql pull --endpoint=<url> [--name=<name>]` fetches an introspection
result and persists SDL + JSON cache artifacts; `zfa graphql diff <name>`
compares the freshly cached schema against the previous one, reports
breaking/non-breaking changes, and exits 1 iff breaking changes exist; the
type mapper covers all built-in scalars + DateTime + custom scalars from
`.zfa.json` `graphql.scalarMap` + nullable/list + naming conventions +
reserved words + union/interface sealed/abstract representations.

### Non-goals

- Authenticated introspection (spec Assumption: public endpoints only).
- Code generation from the schema (existing codegen track, untouched).
- `zfa graphql introspect` behavior changes (kept as-is on top of the new
  throwing fetcher).
- Detecting changes in arguments/default values beyond nullability of fields
  (spec FR-003 enumerates the categories: removed type, removed field, changed
  nullability, added required field; plus enum add/remove from Edge Cases).

### Strategy

1. **MVP slice (P1 — US1)**: introspection client with detailed errors →
   per-name schema cache (JSON + SDL + prev retention) → `zfa graphql pull`.
   Satisfies SC-001 (10s budget) + SC-004 (error paths).
2. **Diff slice (P2 — US2)**: change model + `SchemaDiffer` over `GqlSchema` →
   `zfa graphql diff` with exitCode semantics. Satisfies SC-002 (100% accuracy
   vs committed Vendure fixture).
3. **Type-mapping slice (P3 — US3)**: `dart_type_namer` (camelCase/PascalCase +
   reserved words) + `TypeMapper` extension (DateTime, scalarMap override,
   union/interface representations). Satisfies SC-003.

### Architecture

```
zfa graphql pull ──▶ IntrospectionClient.fetch(url)   (throws on any failure,
                        │                                detail: field/type)
                        ▼
                 GqlSchema.fromIntrospection
                        │
                        ▼
                 SchemaCache.write(name, json, sdl)    (atomic: temp + rename;
                        │                                prev version retained)
                        ▼
       .zfa/graphql/<name>/<name>.schema.{json,graphql}
       .zfa/graphql/<name>.schema.{json,graphql}       (compat copies)
       .zfa/graphql/<name>/<name>.schema.prev.json     (for diff)

zfa graphql diff <name> ─▶ SchemaCache.read(name) + readPrevious(name)
                        ▼
                 SchemaDiffer.diff(oldSchema, newSchema)
                        │
                        ▼
           List<SchemaChange{category: breaking|nonBreaking, kind, ...}>
                        │
                        ▼
                 print report; exitCode = hasBreaking ? 1 : 0
```

`SdlPrinter` renders a `GqlSchema` back to a readable SDL document (type
blocks, field types with `!`/`[...]` wrappers, enums, unions, interfaces,
schema definition). `TypeMapper` consumes `GraphQLType` (parsed AST) as before
and now also exposes `mapTypeRef(GqlTypeRef)` for diff-side rendering; naming
goes through `DartTypeNamer`.

### Risks

- **Spec path ambiguity** (`<name>/` dir vs flat files) — mitigated by the
  dual-layout write + dual-location read documented above.
- **Breaking the 4 existing `SchemaCache` tests** — the legacy
  `save`/`load`/`hasCache` API is preserved verbatim (it addresses the
  single-file layout used by those tests).
- **Fixture realism** — the fixture is hand-shaped to mirror the real Vendure
  Shop API introspection envelope; committed as data so tests are deterministic
  and network-free.

## Changes

### Phase 1: Setup

Fixtures + `IntrospectionClient` + `SdlPrinter` (no CLI yet).

### Phase 2: Cache (P1)

Rewrite `SchemaCache` around per-name layout; wire `zfa graphql pull`.

### Phase 3: Diff (P2)

`SchemaChange` model + `SchemaDiffer`; wire `zfa graphql diff` with exit codes.

### Phase 4: Type mapping (P3)

`DartTypeNamer`; extend `TypeMapper` (DateTime, scalarMap, union/interface
representations).

### Phase 5: Export & Verify

Barrel exports, `dart analyze`, full `dart test`, red/green bookkeeping in
`tdd/verification.md`.

## Sketch

### IntrospectionClient (throwing fetch, injectable transport)

```dart
typedef IntrospectionTransport = Future<Map<String, dynamic>> Function(
    Uri endpoint, Map<String, String> headers, String query);

class IntrospectionException implements Exception {
  IntrospectionException(this.message, {this.statusCode, this.graphqlErrors, this.path});
  final String message;        // human-readable, actionable
  final int? statusCode;       // HTTP status when transport-level
  final List<Map<String, dynamic>>? graphqlErrors; // server-reported errors
  final List<String>? path;    // e.g. ['__schema', 'types', 'Product', 'fields']
}

class IntrospectionClient {
  IntrospectionClient({IntrospectionTransport? transport}); // tests inject
  Future<Map<String, dynamic>> fetch(Uri endpoint, {Map<String, String>? headers});
  // - transport error  -> IntrospectionException('Endpoint unreachable: ...')
  // - status != 200    -> IntrospectionException('HTTP $status: body')
  // - 'errors' in body -> IntrospectionException with graphqlErrors + locations
  // - missing __schema -> IntrospectionException('Introspection response has
  //   no __schema — the endpoint may disable introspection')
  // - null queryType   -> IntrospectionException('schema has no query root type')
}
```

### SchemaCache (per-name layout + prev retention)

```dart
class SchemaCache {
  SchemaCache({required this.cacheDir});   // cacheDir == '.zfa/graphql'
  Future<CachedSchema> pull(String name, {Uri? endpoint, headers, transport});
  //   fetch -> validate -> write json + sdl (atomic) + rotate prev
  Future<void> write(String name, Map<String, dynamic> json); // + SDL derived
  Future<CachedSchema> read(String name);    // throws SchemaCacheError w/ path
  Future<CachedSchema?> readPrevious(String name);
  Future<bool> hasSchema(String name);
  // legacy single-file API kept: load({endpoint,...}), save(json), hasCache()
}

class CachedSchema {
  final String name; final Map<String, dynamic> json;
  final GqlSchema schema; final File jsonFile; final File? sdlFile;
}
```

### SchemaChange / SchemaDiffer

```dart
enum ChangeSeverity { breaking, nonBreaking }
enum ChangeKind { typeRemoved, fieldRemoved, nullabilityChanged,
                  requiredFieldAdded, enumValueRemoved,          // breaking
                  optionalFieldAdded, enumValueAdded, typeAdded } // non-breaking

class SchemaChange {
  final ChangeSeverity severity; final ChangeKind kind;
  final String typeName; final String? fieldName; final String? detail;
}

class SchemaDiff {
  final List<SchemaChange> changes;
  bool get hasBreaking => changes.any((c) => c.severity == breaking);
}

class SchemaDiffer {
  static SchemaDiff diff(GqlSchema oldS, GqlSchema newS);
  // nullability comparison per field via GqlTypeRef.isNonNull chain vs
  // rendered type string (e.g. 'Product' -> 'Product!' or reverse)
}
```

### TypeMapper extension points

```dart
TypeMapper({Map<String, String>? customScalars,        // from .zfa.json scalarMap
            Map<String, String>? typeOverrides,
            NamingConvention convention = NamingConvention.camelCase})

String mapType(GraphQLType t);          // 'int', 'String?', 'List<Product>?'
String mapTypeRef(GqlTypeRef ref);      // diff-side rendering
static String fieldName(String gql);    // camelCase + reserved-word escape
static String className(String gql);    // PascalCase + reserved-word escape
String unionRepresentation(GraphQLUnionType u);   // sealed class Dart source
String interfaceRepresentation(GraphQLInterfaceType i); // abstract class
```

Reserved words (`class`, `int`, `in`, `is`, `new`, `null`, `this`, `default`,
`extension`, `interface`, `mixin`, …) get a `_$` prefix on fields / `$`
suffix on class names, following common graphql_codegen practice.

## Deferred / Future Work

- Authenticated introspection (`--header` flags beyond the existing
  `introspect --headers`).
- Diffing input-object fields and argument signature changes (same engine,
  more categories).
- SDL round-trip parsing (printing only is required here).
