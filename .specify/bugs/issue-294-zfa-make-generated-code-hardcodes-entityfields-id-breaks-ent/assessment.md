# Bug Assessment: zfa make: generated code hardcodes EntityFields.id (breaks entities without id) + mock datasource empty (methods default [])

- **Slug**: issue-294-zfa-make-generated-code-hardcodes-entityfields-id-breaks-ent
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Updated**: 2026-08-22T00:00:00+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/294
- **Verdict**: already fixed in `origin/master`; regression lock added
- **Severity**: unknown

## Report (verbatim or summarized)

zfa make on entities without a literal `id` field (e.g. `StorePrice.depotId`,
`GroceryPriceResult.storeId`) generated code that hardcoded `EntityFields.id`,
and the mock datasource plugin defaulted its method list to `[]`, producing an
empty class that failed `implements`. See https://github.com/arrrrny/zuraffa/issues/294.

## Symptom

Generated presenter/controller/usecase-test files reference `StorePriceFields.id`
for entities that have no such field → `undefined_getter`. Generated mock
datasource implements zero methods → `non_abstract_class_inherits_abstract_member`.

## Reproduction

```bash
zfa entity create -n StorePrice --field depotId:String ...   # no `id`
zfa make StorePrice --preset=crud --with=vpc,state,di,test,mock
flutter analyze   # undefined_getter + non_abstract_class...
```

## Suspected Code Paths

- `lib/src/plugins/presenter/presenter_plugin.dart` — uses `config.idField` /
  `config.queryField` (resolved by `EntityFieldResolver` via MakeCommand). These
  default to `'id'`/`'id'` when not supplied, so callers that failed to resolve a
  real id field emitted `EntityFields.id`.
- `lib/src/plugins/mock/mock_plugin.dart:108` — `methods` defaulted to `[]`
  (unlike di/usecase/test/state/controller/datasource/repository which default to
  `['get','update','toggle']`), so `--preset=crud --with=mock` (without explicit
  `--methods`) produced an empty mock datasource.

## Root Cause Hypothesis

Two distinct gaps:
1. Generators assumed a literal `id` field; entities with a differently-named
   id-like field (no `*Id` / no `--id-field`) hit the `?? 'id'` fallback and
   emitted a nonexistent `EntityFields.id`.
2. Mock plugin defaulted `methods` to `[]`, so the mock datasource builder looped
   over nothing and emitted no method bodies.

## Proposed Remediation (already merged)

1. `mock_plugin.dart` now defaults `methods` to
   `['get', 'update', 'toggle']` (respecting `no-entity` and explicit overrides) —
   merged as #295.
2. Entity-aware id-field resolution (`EntityFieldResolver` + MakeCommand feeding
   `context.data['id-field']` / `['query-field']` which plugins read with `?? 'id'`)
   — merged as #295, complemented by the loud no-id error (#321/#322) and autoId
   (#307/#320).

## Files likely to change

- `lib/src/plugins/mock/mock_plugin.dart` (methods default) — already done.
- `lib/src/plugins/presenter/presenter_plugin.dart` (uses `config.idField`) —
  already done.
- `test/plugins/presenter/presenter_resolved_id_field_test.dart` — added as a
  fast plugin-level regression lock (the existing `test/regression/
  issue_294_entity_without_id_test.dart` covers the resolver + usecase-test side
  via the full `zfa make` path).

## Tests to add

- Plugin-level unit test asserting the generated presenter references the resolved
  field name (`depotId`) and never a hardcoded `id`. See
  `test/plugins/presenter/presenter_resolved_id_field_test.dart`.

## Risks & Considerations

- The presentation-layer (controller/presenter) generators are skipped for
  pure-Dart targets per Constitution VII (Engine Purity); full VPC behaviour is
  covered in the `zuraffa_flutter` package. The added test drives the plugin
  directly and only inspects generated Dart text, so it needs no flutter SDK.
- No `lib/src` change was required for this issue: the fix already ships in
  master. The PR adds only the regression lock and closes the ticket.
