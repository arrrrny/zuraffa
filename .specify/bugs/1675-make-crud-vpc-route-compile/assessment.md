# Bug Assessment: `zfa make` crud+vpc+route emits non-compiling Dart (markStale, untyped path params, gate misattribution)

- **Slug**: 1675-make-crud-vpc-route-compile
- **Assessed**: 2026-09-18
- **Issue**: ./issue.md
- **Severity**: High
- **Status**: Open

---

## Summary

Three independent template/gate defects make the canonical
`zfa make <E> --preset=crud --vpc --route` output fail `zfa build`'s
analyze gate: a repository template that calls a `CachePolicy` method the
published package does not declare, a route plugin path that drops the
entity's id field type so String path parameters flow into typed view
fields, and an analyze-gate ownership classifier that mislabels freshly
generated files as hand-authored.

---

## Root Cause

### Defect 1 — repository template ↔ package API skew (`markStale`)

`lib/src/plugins/repository/generators/implementation_generator_cached.dart`
(=`_buildCacheAwareDeleteBody`, line ~452) emits:

```dart
await _cachePolicy.markStale('todo_cache');
```

`CachePolicy` — in this checkout (`lib/src/core/cache_policy.dart`) and in
the published package (verified against hosted zuraffa 6.x) — declares only
`isValid`, `markFresh`, `invalidate`, `clear`. `markStale` does not exist,
so every cache-aware repository with a `delete` method emits a call that
cannot resolve (`undefined_method` at the consumer).

The compile gate
(`test/plugins/repository/repository_compile_test.dart`, spec 1003 T003)
covers the **cached** variant but pins `methods: ['get']` only — the
cache-aware **delete** body was never compiled by any lane, which is how
the skew escaped.

### Defect 2 — route generator never parses non-String path parameters

`zfa make` resolves the entity's id field and writes it into the shared
plugin context (`make_command.dart` ~line 841:
`context.data['id-field-type'] = resolution.idField!.nonNullableType`).
The view plugin reads it (`view_plugin.dart` ~line 131:
`idFieldType: context.data['id-field-type'] ?? 'String'`) so the generated
view's `id` parameter is typed from the entity (`id:int` → `int?`).

The route plugin does NOT read it:
`RoutePlugin.generateWithContext` (`lib/src/plugins/route/route_plugin.dart`
~lines 238-252) builds its `GeneratorConfig` without `idFieldType`, so the
config defaults to `'String'` and `_buildViewBuilderExpr`
(`route_builder.dart` ~line 1140) falls through the typed-parse switch to
the raw String case, emitting:

```dart
id: state.pathParameters['id']!
```

→ `argument_type_not_assignable` at both the detail and update builders in
`<entity>_routes.dart`. The typed machinery already exists (the `#336`
switch emits `int.parse`/`double.parse`/`num.parse` per `idFieldType`) —
only the plugin-context plumbing is missing. The standalone
`zfa route create` path is unaffected: `CreateRouteCapability` resolves the
id type through `resolveEntityIdFieldType`.

### Defect 3 — analyze-gate misattribution of generator output

`BuildCommand._isGeneratedPath` (`lib/src/commands/build_command.dart`
~line 870) classifies an offending path as generator output only when it
ends in `.zorphy.dart` or `.g.dart`. Files `zfa make` just wrote —
`lib/src/data/repositories/data_todo_repository.dart`,
`lib/src/routing/todo_routes.dart` — carry neither suffix, so the gate's
remedy lines blame them as
`hand-authored offending (not generator output)` and tell the user to fix
"the named files", misdirecting the operator to hand-patch generated code
(and implicitly inviting exactly the kind of manual edit that gets
clobbered by the next regeneration).

---

## Impact

Every crud+vpc+route slice with a non-String id and cache enabled fails
`zfa build` with three errors that all trace back to generator output, and
the gate's remedy tells the user to fix files they did not write.

## Remediation (minimal)

1. **Repository template**: emit `await _cachePolicy.invalidate('<key>');`
   in `_buildCacheAwareDeleteBody` (matches the published API; `invalidate`
   is the honest semantic for delete — the cached entry must be dropped).
   Extend the compile gate's cached variant to include `delete` so the
   cache-aware delete body compiles against the package API in every lane
   from now on.
2. **Route plugin**: mirror the view plugin's context reads in
   `RoutePlugin.generateWithContext` — pass `idField` /
   `idFieldType` (and `queryField`/`queryFieldType` for consistency) from
   `context.data` into the `GeneratorConfig`. No change to route semantics
   or the existing `#336` typed-parse switch.
3. **Analyze gate**: extend `_isGeneratedPath` to also recognize the
   directory conventions `zfa make` owns under the output dir
   (`domain`, `data`, `di`, `routing`, `presentation`, `cache`), with
   backslash normalization for Windows analyzer output; reword the
   generated-group label accordingly. Hand-authored files outside those
   conventions keep the honest hand-authored remedy.

## Hard constraints honored

- No change to the `CachePolicy` package API.
- No change to route semantics (the emitted parse form stays the `#336`
  `int.parse(state.pathParameters['id']!)` shape the route table test
  already pins).
- One PR per bug; fix all three defects; full repro compiles without
  hand-patching.
