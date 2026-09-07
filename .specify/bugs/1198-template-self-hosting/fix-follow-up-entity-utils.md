# Fix follow-up — phantom entity imports from generic flattening

Branch: `fix/1198-followup-phantom-entity-imports`
Scope: spec-1003 finding #7 follow-up ("flagged here as follow-up material
for the mock plugin owners") — hardens the #1198 referee bar.

## Defect (reproduced on merged master, PR #1228 line)

`EntityUtils.extractEntityTypes` flattened framework param wrappers:
`QueryParams<Product>` → `QueryParamsProduct`,
`ListQueryParams<Product>` → `ListQueryParamsProduct`. The mock provider
builder extracts the service interface's methods from disk
(`MethodExtractor.extractMethodsFromInterface`) and feeds their signatures
through `extractEntityTypes` — so in the canonical `zfa make` plugin order
(service emitted before mock, service lane) the emitted
`product_mock_provider.dart` imported files nobody generates:

- `domain/entities/query_params_product/query_params_product.dart`
- `domain/entities/list_query_params_product/list_query_params_product.dart`
- `data/mock/query_params_product_mock_data.dart`
- `data/mock/list_query_params_product_mock_data.dart`

`dart analyze` fails with four `uri_does_not_exist` errors — a template-
level import/dep drift of exactly the class the #1198 loop exists to
catch. Red evidence (this branch, before the fix):

```
Expected: ['Product']  Actual: ['QueryParamsProduct']
Expected: ['Product']  Actual: ['ListQueryParamsProduct']
Expected: ['Order']    Actual: ['ParamsOrder']
```

## Fix

`lib/src/utils/entity_utils.dart`: strip framework param/contract wrappers
(`QueryParams`, `ListQueryParams`, `UpdateParams`, `DeleteParams`,
`InitializationParams`, `Params`, `Filter`, `Sort`) BEFORE flattening
generics — the wrapper is a zuraffa param type, not an entity; the entity
is its type argument. All 42 `extractEntityTypes` call sites benefit.

## Regression test

`test/utils/entity_utils_wrapper_strip_test.dart` — 5 tests pinning the
wrapper-strip contract (all eight wrappers, plain/List-wrapped
pre-existing behavior, bare wrapper names still excluded, nested
`List<QueryParams<T>>`).

## Verification (real counts, this branch)

| Suite | Result |
|---|---|
| `test/utils/` | 104/104 |
| `test/templates/self_hosting/` (merged #1228 loop, pure-Dart lane) | 44/44 |
| `test/plugins/mock/` | 147/147 |
| `test/plugins/repository/` | 48/48 |
| `test/plugins/datasource/` | 41/41 |
| `test/plugins/service/` | 29/29 |
| `test/plugins/usecase/` | 42/42 |
| `test/plugins/state/` | 21/21 |
| `test/plugins/route/` | 97/97 |

`dart analyze lib/src/utils/entity_utils.dart
test/utils/entity_utils_wrapper_strip_test.dart` → No issues found;
`dart format` clean.
