# Test List: 1675-make-crud-vpc-route-compile

## Outer loop: acceptance behaviors

One per acceptance criterion in `assessment.md` → Remediation.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the cache-aware delete body emits a `CachePolicy` call that exists in the published package (`invalidate`), and never `markStale` | Defect 1 | GREEN |
| A2 | the cache-aware delete body compiles against the package API in the spec-1003 compile gate (cached variant includes `delete`) | Defect 1 | GREEN |
| A3 | the route plugin's `zfa make` path (`generateWithContext`) emits typed path-param parsing (`int.parse(state.pathParameters['id']!)`) for an int-id entity, and never a raw String assignment into the typed view field | Defect 2 | GREEN |
| A4 | the analyze gate attributes `zfa make` output files (`lib/src/data/repositories/*.dart`, `lib/src/routing/*_routes.dart`) to generator output — the remedy points at the generator, not the user | Defect 3 | GREEN |
| A5 | hand-authored files outside the generator's directory conventions keep the honest hand-authored attribution (no over-attribution) | Defect 3 | GREEN |

## Outer loop: widget behaviors

Not applicable — the defect surface is the pure-Dart generator engine
(repository/route plugins, build gate); no widget scenario is derivable.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `assessment.md` → Remediation.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `_buildCacheAwareDeleteBody` emits `await _cachePolicy.invalidate('<key>');` (the published API) | Defect 1 | GREEN |
| U2 | `RoutePlugin.generateWithContext` forwards `context.data['id-field-type']` into the `GeneratorConfig` it builds (mirror of `view_plugin.dart`'s read) | Defect 2 | GREEN |
| U3 | `_isGeneratedPath` recognizes the make-owned directory conventions (`domain`/`data`/`di`/`routing`/`presentation`/`cache` under the output dir), normalizing Windows backslashes | Defect 3 | GREEN |

## Notes

- RED/GREEN evidence: one driver file
  `test/fixes/bug_1675_make_crud_vpc_route_compile_test.dart` (fast,
  pure-Dart, in-process) plus the spec-1003 compile gate extension in
  `test/plugins/repository/repository_compile_test.dart` (cached variant
  gains `delete`, so the delete body compiles against the package API).
- The compile gate is the "compiles the emitted repository against the
  published package" referee the assessment requires; the driver file pins
  the emitted-source contract for the fast lane.
- RED evidence (pre-fix, this session): 5/5 driver tests failed for the
  RIGHT reasons; the extended compile gate failed with
  `undefined_method` on `markStale` with the generator fix reverted.
- GREEN evidence (post-fix, this session): driver 5/5, route plugin 115,
  repository 54, gate unit suite 55, compile gate 1 — all green. Full
  transcript: ./verification.md
