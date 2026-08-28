# Bug Issue: zfa make: generated code hardcodes EntityFields.id (breaks entities without id) + mock datasource empty (methods default [])

- **Slug**: issue-294-zfa-make-generated-code-hardcodes-entityfields-id-breaks-ent
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 294
- **URL**: https://github.com/arrrrny/zuraffa/issues/294
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` with ONLY zfa commands). The vertical slice passes (analyze 0 errors with #293), so I generated the **grocery cluster**: 8 entities (`zfa entity create`), then `zfa make <Entity> --preset=crud --with=vpc,state,di,test,mock` for each. `zfa make` and `zfa build` succeed, but `flutter analyze` on the cluster = **26 errors** in two distinct classes.

## Repro

```bash
zfa setup zikzak_demo --flutter --platforms=ios,macos,android
zfa entity create -n StorePrice --field depotId:String ...   # NOTE: no `id` field
zfa entity create -n GroceryPriceResult --field storeName:String ...   # NOTE: no `id` field
zfa entity create -n GroceryItem --field id:String --field canonicalName:String ...   # HAS id
zfa make StorePrice --preset=crud --with=vpc,state,di,test,mock
zfa make GroceryItem --preset=crud --with=vpc,state,di,test,mock
zfa build
flutter analyze
```

## Gap 1: generated code hardcodes `EntityFields.id` — breaks entities without an `id` field

Entities in the reference app that legitimately have **no `id` field** (e.g. `StorePrice` uses `depotId`, `GroceryPriceResult` uses `storeName`, `GroceryPriceComparison` uses `itemName`) produce broken generated code:

```
error • The getter 'id' isn't defined for the type 'StorePriceFields'   (undefined_getter)
  - test/domain/usecases/store_price/toggle_store_price_usecase_test.dart  (3x)
  - test/domain/usecases/store_price/get_store_price_usecase_test.dart     (2x)
  - lib/src/presentation/pages/store_price/store_price_presenter.dart      (1x)
  - same pattern for GroceryPriceResult (6x), GroceryPriceComparison (6x)
```

The generated presenter/tests reference `StorePriceFields.id` / `GroceryPriceResultFields.id` as the toggle/get field. For entities without `id`, the Fields class has no `id` member (only `depotId` etc.). The generators must resolve the entity's actual id field (first field, or a field named `id`/`*Id`) instead of hardcoding `id`.

## Gap 2: mock datasource generates an empty class — methods default `[]` in mock plugin

The generated mock datasource implements the interface but has **zero method bodies**:

```dart
class GroceryItemMockDataSource with Loggable, FailureHandler implements GroceryItemDataSource {
  GroceryItemMockDataSource([Duration? delay]) : _delay = delay ?? const Duration(milliseconds: 100);
  final Duration _delay;
  // NO get/update/toggle methods
}
```

```
error • Missing concrete implementations of 'GroceryItemDataSource.get', 'GroceryItemDataSource.toggle', and 'GroceryItemDataSource.update'. (non_abstract_class_inherits_abstract_member)
  - 8 mock datasources affected (all grocery entities)
```

Root cause: `lib/src/plugins/mock/mock_plugin.dart:103` defaults `methods` to `[]`:

```dart
methods: context.data['methods']?.cast<String>().toList() ?? [],
```

while the DI/usecase/test plugins were fixed (#287/#289) to default to `['get', 'update', 'toggle']`. The mock datasource builder (`mock_datasource_builder.dart:355`) loops `for (final method in config.methods)` — with an empty list it emits no methods, producing a class that fails `implements`. When `--methods=get,getList` is passed explicitly, the mock datasource generates correctly (per earlier tests).

## Suggested fix

1. **Gap 1**: entity-aware id-field resolution — use the entity's actual id field (a field literally named `id`, or the first field ending in `Id`, or `--id-field`) in presenter/toggle/get generators instead of hardcoded `EntityFields.id`.
2. **Gap 2**: mock plugin default methods to `['get', 'update', 'toggle']` (same as the other plugins) so `--preset=crud` produces full mock datasources.

## Impact

Blocks the grocery cluster (and every entity without a literal `id` field, plus every `--with=mock` generation without explicit `--methods`). The reference ZikZak app has multiple entities without `id` fields (StorePrice, GroceryPriceResult, GroceryPriceComparison, Barcode, ListingOffer, TelemetryEvent, ...), so full screen parity cannot be reached until Gap 1 is fixed.


## Comments

**coderabbitai** (2026-08-13T05:59:09Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#145 - 008 mock json method [closed]
arrrrny/zuraffa#286 - fix: zfa make canonical command (printed by setup) produces non-compiling code: missing data repo impl + missing orchestrator usecase [merged]
arrrrny/zuraffa#287 - fix(zfa make): always generate data repo impl + wire per-method DI for entity presets (`#284`) [merged]
arrrrny/zuraffa#291 - fix(zfa make): v6 presentation imports use zuraffa_flutter + wire json_annotation (`#281`) [merged]
arrrrny/zuraffa#293 - fix(zfa make): toggle field type uses Field<Entity, dynamic> not EntityFields (`#292`) [merged]
</details>

---
<details>
<summary>📝 Issue Planner</summary>

<sub>Check the box below or use the `@coderabbitai plan` command to generate an implementation plan and prompts that you can use with your favorite coding assistant.</sub>

- [ ] <!-- {"checkboxId": "8d4f2b9c-3e1a-4f7c-a9b2-d5e8f1c4a7b9"} --> Create Plan
</details>


---
<details>
<summary> 🧪 Issue enrichment is currently in open beta.</summary>


You can configure auto-planning by selecting labels in the issue_enrichment configuration.

To disable automatic issue enrichment, add the following to your `.coderabbit.yaml`:
```yaml
issue_enrichment:
  auto_enrich:
    enabled: false
```
</details>

💬 Have feedback or questions? Drop into our [discord](https://discord.gg/coderabbit)!
