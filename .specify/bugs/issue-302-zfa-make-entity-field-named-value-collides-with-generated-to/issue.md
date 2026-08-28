# Bug Issue: zfa make: entity field named 'value' collides with generated toggle params → duplicate_definition in controller/presenter (Barcode)

- **Slug**: issue-302-zfa-make-entity-field-named-value-collides-with-generated-to
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 302
- **URL**: https://github.com/arrrrny/zuraffa/issues/302
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` with ONLY zfa commands). After #299 was fixed (#301), re-ran `zfa make` for the listing subtypes — those are clean now, but `flutter analyze` shows **4 errors** in the generated `Barcode` controller/presenter. The `Barcode` entity has a field literally named `value`.

## What I ran

```bash
zfa entity create -n Barcode --field value:String --field format:BarcodeFormat
zfa make Barcode --preset=crud --with=vpc,state,di,test,mock
zfa build
flutter analyze
```

## Expected

Generated controller/presenter compile.

## Actual

```
error • The name 'value' is already defined. Try renaming one of the declarations
  • lib/src/presentation/pages/barcode/barcode_controller.dart:29:10  (duplicate_definition)
error • The argument type 'String' can't be assigned to the parameter type 'bool'.
  • lib/src/presentation/pages/barcode/barcode_controller.dart:35:7   (argument_type_not_assignable)
error • The name 'value' is already defined. Try renaming one of the declarations
  • lib/src/presentation/pages/barcode/barcode_presenter.dart:47:10   (duplicate_definition)
error • The argument type 'String' can't be assigned to the parameter type 'bool'.
  • lib/src/presentation/pages/barcode/barcode_presenter.dart:54:16   (argument_type_not_assignable)
```

Generated code (barcode_controller.dart):

```dart
Future<void> toggleBarcode(
  String value,                    // <-- id param named `value`
  Field<Barcode, dynamic> field,
  bool value, [                    // <-- toggle value ALSO named `value` → collision
  CancelToken? cancelToken,
]) async {
  final result = await _presenter.toggleBarcode(
    value,   // String
    field,
    value,   // bool — but the String `value` shadows it
    cancelToken,
  );
  ...
```

## Root cause

The toggle-method generator names the **id parameter** after the entity's id field, and the **toggle-value parameter** after the entity's value-ish field. When the entity has a field literally named `value` (as `Barcode` does — `String get value`), both parameters end up named `value`:

- `String value` (id, typed `String`)
- `bool value` (toggle value)

→ `duplicate_definition` (two `value` params) and `argument_type_not_assignable` (the `String` id shadows the `bool` toggle value when forwarded).

The `Barcode` entity is in the reference ZikZak (`String get value; BarcodeFormat get format;`), so this is a real-world case, not an edge contrivance. Any entity with a `value` field (common: barcode value, price value, score value...) triggers it.

## Suggested fix

The toggle generators (controller + presenter) must produce **distinct parameter names** — never reuse the entity field name for the toggle-value parameter. Options:

1. Name the toggle-value param `toggleValue` (or `newValue`) instead of the entity field name; keep the id param as the id field name.
2. If the entity field name collides with a generated parameter (id/`field`/`cancelToken`), suffix with `Value` / use a fixed reserved name.
3. Add a generator-wide guard: collect all generated parameter names; on collision, disambiguate deterministically.

Audit all method generators (toggle/get/update/create/delete) for the same collision pattern — `field`, `value`, `id`, `params`, `cancelToken` are the usual reserved names to check against entity fields.

## Impact

Blocks the `Barcode` entity (scan-barcode route module). Fix is small and localized to the toggle method templates in controller/presenter generators.


## Comments

**coderabbitai** (2026-08-13T16:53:23Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#140 - Development [closed]
arrrrny/zuraffa#287 - fix(zfa make): always generate data repo impl + wire per-method DI for entity presets (`#284`) [merged]
arrrrny/zuraffa#290 - fix(test builder): add toggle case to per-method entity test generator (`#289`) [merged]
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
