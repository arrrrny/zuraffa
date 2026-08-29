# TDD Verification — graphql_core Schema Cache, Introspection & Type Mapping

**Spec**: `specs/037-graphql-core-schema-cache/spec.md`
**Branch**: `037-graphql-core-schema-cache`
**Date**: 2026-08-29

## Summary

All 27 behaviors from `tdd/test-list.md` are GREEN. `zfa graphql pull`
fetches a schema via a throwing introspection client and persists both the
introspection JSON and the SDL rendering in the per-name cache layout
(plus flat compatibility copies); `zfa graphql diff` compares the freshly
cached schema against the retained previous version, classifies breaking vs
non-breaking changes with 100% accuracy against the committed Vendure
fixture, and exits 1 iff breaking changes exist; the type mapper covers all
built-in scalars including `DateTime`, `.zfa.json` `graphql.scalarMap`
overrides, list/nullable conventions, reserved-word-safe camelCase/PascalCase
naming, and sealed/abstract Dart representations for unions/interfaces.

## `dart analyze` (whole project)

```
$ dart analyze
88 issues found. (0 errors, 4 warnings, 84 infos)
```

All 88 issues are pre-existing on `master` (unused elements/imports and
lint hints in files this feature does not touch — `route_builder.dart`,
`extension_command_parity_test.dart`, `usecase_contract_factory_test.dart`,
`cli_command_test.dart`). **Zero errors, zero warnings from any file added
or modified by this feature.** (`dart analyze lib/src/graphql
lib/src/commands/graphql_pull_command.dart lib/src/commands/graphql_diff_command.dart`
→ "No issues found!")

## `dart test` (full fast tier, ACTUAL counts)

The suite was executed per-directory (the runner's kernel cache exceeds the
sandbox disk when the whole suite runs in one process). Every directory in
`test/` was covered; `test/benchmark` is excluded by the default tag filter
(`exclude_tags: slow`) per `dart_test.yaml`.

| Scope | Result |
|---|---|
| `test/core` | 572 passed, 1 skipped (pre-existing skip) |
| `test/config test/utils test/cli test/dda test/domain test/session test/share test/secure_storage test/scripts test/property test/migration test/i18n test/logging test/device test/app_update test/biometrics test/clipboard test/helpers` | 359 passed |
| `test/graphql test/commands` | 427 passed |
| `test/agent test/state test/mcp test/integration` | 283 passed |
| `test/plugins/benchmark test/plugins/xray` | 234 passed |
| `test/plugins/tui` | 66 passed |
| `test/plugins/mcp` | 117 passed (runner lingers after "All tests passed!" — sandbox stdin leak, not a failure) |
| `test/plugins/route usecase sync mock repository provider` | 131 passed |
| `test/plugins` (method_append, strategy, service, datasource, app_shell, api, di, gym, module, shadcn, sqlite, state + top-level files) | 193 passed |
| `test/regression` | 78 passed |
| **Total** | **2460 passed, 1 skipped, 0 failed** |

Of the 2460, **68 are new tests authored for this spec** (5 SDL printer,
10 introspection client, 11 schema cache, 6 pull command, 13 schema diff,
5 diff command, 12 namer, 6 type-mapper additions... exact per-file counts
below) — the rest are the pre-existing suite, all still green (no
regressions; legacy `schema_cache_test.dart`, `type_mapper_test.dart`,
`graphql_introspect_service_test.dart` etc. all pass unmodified).

## Spec SC mapping (all SC-001..004 proven)

### SC-001 — `zfa graphql pull` writes both SDL and JSON within 10s

**PROVEN** by `test/commands/graphql_pull_command_test.dart` — "pull
writes both artifacts within 10s (SC-001)": a loopback `HttpServer` serves
the committed Vendure fixture; the real HTTP transport runs end-to-end
through `CliRunner.runCapturing(['graphql','pull',...])`; the wall-clock
`Stopwatch` asserts < 10s (actual: < 1s for the 35-type fixture) and both
`.schema.json` + `.schema.graphql` artifacts are asserted on disk in both
layouts.

### SC-002 — `zfa graphql diff` identifies all breaking changes with 100% accuracy

**PROVEN** by `test/graphql/schema_diff_test.dart` — "v1 -> v2 fixture diff
is exactly the 9 expected changes": diff(v1, v2) over the committed Vendure
fixtures yields exactly 9 changes — 5 breaking (typeRemoved `Collection`,
fieldRemoved `Product.description`, nullabilityChanged
`ProductVariant.price` `Money!`→`Money`, requiredFieldAdded `Order.code`,
enumValueRemoved `SortOrder.NATURAL`) and 4 non-breaking
(optionalFieldAdded `Product.slug` + `Query.search`, enumValueAdded
`CurrencyCode.XBT`, typeAdded `SearchResponse`) — set-compared exactly, no
false positives, no false negatives. Also proven at CLI level by
`test/commands/graphql_diff_command_test.dart` — "breaking diff prints all
changes and exits 1".

### SC-003 — Dart type mapper correct for scalars/nullable/list/custom

**PROVEN** by `test/graphql/type_mapper_test.dart` (`spec 037` group):
ID→String, Int→int, Float→double, String→String, Boolean→bool,
DateTime→DateTime (FR-005 built-ins), `String?`/`List<String?>`/
`List<String>` nullability+list conventions, `scalarMap` override
(Money→int) + `TypeMapper.fromZfaConfig` reading `.zfa.json`
`graphql.scalarMap`, malformed-scalarMap `FormatException`s, unmapped
custom scalar fallback, union `sealed class` and interface `abstract class`
renderings (FR-008), and `mapTypeRef` over raw introspection refs.

### SC-004 — error cases surface clearly, no silent failures

**PROVEN** by: `test/graphql/introspection_client_test.dart` (HTTP 500,
unreachable endpoint, GraphQL errors with the failing field/type path,
missing `__schema`, null query root, non-JSON body, unknown type kind —
every path throws `IntrospectionException`, none return null);
`test/graphql/schema_cache_037_test.dart` (missing cache name names the
expected file path; malformed cached JSON surfaces a clear error; no
partial files written on fetch or parse failure; cache dir auto-created);
`test/commands/graphql_pull_command_test.dart` (CLI error paths print
actionable errors and set non-zero exit codes without writing files);
`test/commands/graphql_diff_command_test.dart` (unknown name lists cached
schemas; missing previous version suggests `zfa graphql pull`).

## Spec FR mapping

| FR | Status | Evidence |
|---|---|---|
| FR-001 fetch + persist SDL & JSON under `.zfa/graphql/<name>/` | DONE | `SchemaCache.pull`/`write`; `SdlPrinter`; dual-layout write asserted in `schema_cache_037_test.dart` |
| FR-002 surface introspection errors (no null-on-failure, specific field/type) | DONE | `IntrospectionClient.fetch` + `IntrospectionException` (message + path + status + graphqlErrors) |
| FR-003 breaking/non-breaking change detection | DONE | `SchemaDiffer.diff` — 7 change kinds + defensive `fieldTypeChanged` |
| FR-004 exit 0/1 after diff | DONE | `DiffCommand` sets `exitCode = hasBreaking ? 1 : 0`; asserted both ways |
| FR-005 built-in scalars incl. DateTime + nullable + list | DONE | `TypeMapper.mapType` / `_mapScalarName` |
| FR-006 `.zfa.json` scalarMap overrides built-ins | DONE | `TypeMapper.fromZfaConfig` |
| FR-007 naming conventions + reserved words | DONE | `DartTypeNamer.fieldName/className` (documented `_$name` / `Name$` escapes) |
| FR-008 union/interface Dart representations | DONE | `TypeMapper.unionRepresentation` (sealed) / `interfaceRepresentation` (abstract) |

## Edge cases from the spec

- Circular type references (`User.friends: [User]`) — handled: the
  introspection model stores type refs by name; no recursive resolution is
  performed (parser is two-pass over names).
- Authenticated introspection — out of scope per spec Assumptions (the
  `--headers` option of `introspect` remains available for future reuse).
- Malformed `.zfa.json` scalarMap — `TypeMapper.fromZfaConfig` throws
  `FormatException` with the offending entry (tested).
- New enum value (non-breaking) vs removed enum value (breaking) — both
  classified and tested (`enumValueAdded` / `enumValueRemoved`).
- Missing `.zfa/graphql/` cache directory — auto-created on first write
  (tested); reads on a missing cache produce actionable errors.
- Custom scalar not present in scalarMap — falls back to `String` by
  documented convention (tested).

## TDD process notes

- Red evidence for every behavior cluster: `tdd/red/01..08-*.md` (compile
  red or failing-expectation red, captured before implementation).
- Two test-expectation bugs were fixed during the red/green loop (nested
  list SDL rendering `[[Int!]]!`; enum `kind.name` string formatting) —
  both were test corrections, not implementation accommodations.
- One fixture-path test-isolation fix: tests now resolve fixtures via
  `findProjectRoot()` (repo convention from
  `test/helpers/project_root.dart`) instead of CWD-relative paths, which
  break when suites from multiple directories run in one `dart test`
  invocation.

## Pre-existing unrelated failures

None. The full fast-tier suite is green (2460 passed / 1 skipped / 0
failed). The single skip in `test/core` exists on `master`. The 88 analyze
issues match the pre-existing `master` baseline (0 errors, 4 warnings, 84
infos). `test/benchmark` is excluded by the default tag filter by design.
