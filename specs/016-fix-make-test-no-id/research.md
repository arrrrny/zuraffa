# Research: make --test regenerates tests for id-less entities

**Feature**: 016-fix-make-test-no-id | **Date**: 2026-08-27

This file records the Phase 0 research that resolved the plan's open questions. Every finding below was verified against the master checkout (commit `631af1a0`).

## R1. Where exactly does the loud failure fire, and what runs before it?

`lib/src/commands/make_command.dart`, `run()`:

1. `manager.resolvePlan(...)` → `plan.activePlugins` (line ~348–360) — the plugin set is already known at this point.
2. `manager.buildContext(...)` (line ~366) → `context.data` merged with normalized options.
3. **Entity resolution block** (lines ~385–482): calls `EntityFieldResolver.resolveIdField`. Three branches:
   - value object → drop root plugins (incl. `test`) with a notice — untouched by this change;
   - `hasId` → populate `id-field` / `id-field-type` / `query-field` unless the user passed them;
   - **no id → print the #307 diagnostic + throw `MakeCommandException`** (lines 442–480) — THE over-application: it runs before plugin dispatch, so it fires for any active plugin set, including `--test` alone.
4. Only then: `manager.run(context, activePlugins)` → per-plugin `validate`/`beforeGenerate`/`generateWithContext`.

So the plugin set is available **before** the throw — the gate can be a pure set intersection over `activePlugins`. No reordering of the pipeline is needed; the diff is local to the else-branch.

## R2. Which plugins are id-DEPENDENT (their generated signatures embed an id)?

Survey of every plugin under `lib/src/plugins/` for id-typed tokens (`idField`, `idFieldType`, `UpdateParams<...>`, `DeleteParams<...>`, `ToggleParams<...>`, id-keyed operations) in **emitted** code:

| Plugin | Evidence (file) | Verdict |
|---|---|---|
| repository | `generators/interface_generator.dart` — `UpdateParams<idType,...>` | dependent (named in issue) |
| datasource | `builders/interface_generator.dart`, `remote_generator.dart` — `UpdateParams`/`ToggleParams`/`DeleteParams` | dependent (named) |
| usecase | `generators/entity_usecase_generator.dart` | dependent (named) |
| controller | `controller_plugin*.dart` — params typed by `idFieldType` | dependent (named) |
| presenter | `presenter_plugin.dart` | dependent (named) |
| service | `builders/service_interface_builder.dart:168,179` — `UpdateParams<${config.idFieldType},...>`, `DeleteParams<${config.idFieldType}>` | dependent |
| provider | `builders/provider_builder.dart:375,386` — same pattern | dependent |
| route | `builders/route_builder.dart:198,565,945` — id-typed route params (`allowIdRoutes`) | dependent |
| gql | `builders/gql_builder.dart:203-241` — id-keyed operation variables | dependent |
| graphql | `builders/graphql_builder.dart:208-246` — same | dependent |
| sqlite | `builders/sqlite_datasource_builder.dart:63,253,265` — id in SQL + `UpdateParams` | dependent |
| api | `builders/api_bridge_builder.dart:171+` — bridges id-typed usecase params | dependent |
| sync | `builders/sync_builder.dart:260` — `getByIds(keys)` | dependent |
| view | `capabilities/create_view_capability.dart:134` — #336: types the route id param so `onInitState` passes the presenter an id | dependent |
| test | `test_plugin.dart:100-103` reads `id-field`/`query-field` only to *reference* Field constants; regenerates from existing usecases | **neutral (per issue)** |
| mock | reads `id-field`/`query-field`; the issue explicitly classifies mock generation as id-neutral | **neutral (per issue)** |
| gym | `gym_plugin.dart` — "mirrors TestPlugin exactly" (class doc); same regeneration-from-existing shape | neutral |
| di | registers usecases; no id in signatures | neutral |
| cache | Hive adapters are field-based; no id signature found | neutral |
| state, observer, module, app_shell, feature, method_append, strategy, xray, mcp, shadcn | no id usage found | neutral |

**Decision** — the named set (greppable, single declaration):

```
repository, datasource, usecase, controller, presenter,
service, provider, route, view, gql, graphql, sqlite, api, sync
```

This is intentionally a superset of the issue's named five (all verified signature-level embedders) and intentionally excludes the issue's named neutral pair (`test`, `mock`) plus their structural siblings (`gym`, `di`, `cache`, ...).

## R3. What does the id-neutral path need after the throw is skipped?

The test plugin (`test_plugin.dart:100-103`) builds its `GeneratorConfig` from `context.data['query-field']` (default `'id'`) and `context.data['query-field-type']` (falls back to `id-field-type`, then `'String'`, inside `GeneratorConfig`'s constructor). The per-method test builder (`test_builder_helpers.dart`) then emits:

- `get`: `QueryParams<E>(filter: Eq(EFields.<queryField>, <queryValue>))`
- `toggle`: `ToggleParams<idType, Field<E, dynamic>>(id: ..., field: EFields.<queryField>, value: true)`
- `update`: `UpdateParams<idType, EPatch>(id: ..., data: ...)`

`<queryValue>` is `literalNum(1)` when `queryFieldType == 'int'`, else `literalString('1')`. Consequence: a query field typed `String` or `int` compiles cleanly; a custom/enum type would not. **The representative field must therefore prefer String (then int) fields, and must never be enum-typed.** `--test` skips files whose usecase source is missing (`⚠️ Skipping test generation`), so regeneration on the id-neutral path degrades gracefully even in partial projects.

## R4. How to detect "enum-typed" cheaply and without touching builders?

`EntityFieldResolver.parseEntityFields()` (already public and unit-tested) returns declaration-order `EntityFieldInfo(name, type)`. A field is a safe query key iff its non-nullable type is a scalar primitive — checked against `KnownTypes.dartPrimitives` (`lib/src/core/constants/known_types.dart`). Preference order:

1. first non-nullable `String` field
2. first non-nullable `int` field
3. first nullable `String`/`int` field
4. first non-enum-ish scalar (`double`, `num`, `bool`, `DateTime`) — best-effort tail

Custom identifiers (enums, other classes) are never chosen — this is strictly safer than the removed pre-#307 first-field fallback and honours FR-005. New API lives in the resolver (`resolveRepresentativeField`), keeping `lib/src/plugins/test/builders/*` untouched per the mergeability constraint.

## R5. Existing test patterns to follow

- `test/commands/make_command_test.dart` — group `MakeCommand #307 identity contract` runs `zfa` from source (`bin/zfa.dart`) as a subprocess in a temp workspace with hand-written entity files; asserts exit codes and stdout contents. The same file's earlier tests use `CliRunner(exitOnCompletion: false).runCapturing([...])` in-process, which catches `MakeCommandException` in the zone (per the comment at the throw site: "Thrown (not `exit(1)`) so ... `runCapturing` tests can assert on the message without killing the test isolate").
- `test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart` — the #307/#321 contract tests (full make must exit 1; `--id-field` must not conjure an identity). These must stay green untouched — they are the #307 regression proof.
- `dart_test.yaml` + `test/README.md`: default run = fast suite; slow tiers behind presets.

## R6. Reproduction status (before any fix)

A local `zikzak_demo` stand-in (apps/zikzak_demo is not part of this repo) was built with zfa itself: entities generated with a temporary id, full repository/datasource/usecase/test architecture generated, id then stripped, `zfa build` re-run. `zfa make AuthRequest --test --force` on unmodified master exits 1 with the exact issue output:

```
❌ Cannot generate architecture for "AuthRequest": the entity has no id field.
...
❌ Error: Cannot generate architecture for "AuthRequest": the entity has no id field.
```

The stale tests reference `EFields.id` (now non-existent) — precisely zikzak_demo's blocked state.

## R7. Open questions resolved

- **Does anything else block id-less entities after the throw is skipped?** `_validateEntityFirstPreconditions` (plugin_manager.dart:761) only requires the entity *file* to exist — no id check. Plugin `validate()` hooks: test plugin has none beyond base. Nothing else blocks.
- **Value objects with `--test`?** Unchanged: the value-object branch drops `test` from activePlugins with a notice (test is in `_valueObjectRootPlugins`) — pre-existing behaviour, out of scope.
- **User-passed `--query-field`?** Must win — same `wasParsed` guard style as the `hasId` branch.
