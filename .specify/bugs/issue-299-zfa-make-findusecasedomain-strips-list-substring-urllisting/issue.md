# Bug Issue: zfa make: findUseCaseDomain strips '_list' substring → UrlListing/TextListing/BarcodeListing presenter imports mangled (urling/texting/barcoding)

- **Slug**: issue-299-zfa-make-findusecasedomain-strips-list-substring-urllisting
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 299
- **URL**: https://github.com/arrrrny/zuraffa/issues/299
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` with ONLY zfa commands). Grocery cluster + next-cluster entities pass. After `zfa make` on the listing-subtype entities (`UrlListing`, `TextListing`, `BarcodeListing`), `flutter analyze` shows **22 errors** in their generated presenters.

## What I ran

```bash
zfa entity create -n UrlListing --field id:String --field title:String --field url:String   # etc for TextListing/BarcodeListing
zfa make UrlListing --preset=crud --with=vpc,state,di,test,mock    # etc
zfa build
flutter analyze
```

## Expected

Generated presenters import the per-method usecases from the correct directory (`domain/usecases/url_listing/get_url_listing_usecase.dart`).

## Actual

The presenter's `get`/`update` usecase imports use a **truncated domain path**:

```dart
// lib/src/presentation/pages/url_listing/url_listing_presenter.dart (generated)
import '../../../domain/usecases/toggle_url_listing.dart';          // wait — actual:
import '../../../domain/usecases/toggle_url_listing_usecase.dart';  // correct
import '../../../domain/usecases/urling/get_url_listing_usecase.dart';   // BUG: "urling"
import '../../../domain/usecases/urling/update_url_listing_usecase.dart'; // BUG
```

Pattern across all three subtypes:
- `url_listing` → `urling`
- `text_listing` → `texting`
- `barcode_listing` → `barcoding` (also present in `barcode_presenter.dart`/`barcode_controller.dart`)

`toggle_*` imports resolve correctly; only `get_*`/`update_*` (and presumably `create_*`/`delete_*`/`watch_*`/`getList`-style) are mangled. Result: `Undefined class 'GetUrlListingUseCase'` / `UpdateUrlListingUseCase` / etc.

## Root cause

`CommonPatterns.findUseCaseDomain` (lib/src/core/builder/patterns/common_patterns.dart:246-299). After active discovery fails, the prefix-based fallback:

```dart
final possiblePrefixes = ['get_', 'create_', 'update_', 'delete_', 'watch_'];
for (final prefix in possiblePrefixes) {
  if (usecaseSnake.startsWith(prefix)) {
    final entitySnake = usecaseSnake
        .replaceFirst(prefix, '')
        .replaceFirst('_list', '');   // <-- BUG
    return entitySnake;
  }
}
```

The `.replaceFirst('_list', '')` is meant for **list-method** usecases (`get_product_list` → `product`), but it strips `_list` from **any** position. For entity names ending in `_listing` (a word, not the `_list` suffix): `get_url_listing` → strip `get_` → `url_listing` → strip `_list` (matches inside `url_` + `listing`? no — matches literally `_list` substring: `url_listing` contains `_list` at `url`+`_list`+`ing`) → `urling`. Same for `text_listing` → `texting`, `barcode_listing` → `barcoding`.

Why `toggle_*` works: `toggle` is not in `possiblePrefixes`, so it falls to the active discovery branch / default domain which finds the real directory.

## Suggested fix

Only strip `_list` when it is a **suffix** of a list-method usecase name, and only for the known list prefixes (`get_list`/`watch_list`/`create_list`-style patterns), not as a raw substring:

```dart
final entitySnake = usecaseSnake.replaceFirst(prefix, '');
// strip trailing `_list` ONLY for list-style usecases (get_list, watch_list, getList)
if (usecaseSnake.startsWith('${prefix}list')) {
  return entitySnake.replaceFirst(RegExp(r'_list$'), ''); // or endsWith('_list')
}
return entitySnake;
```

Better: check `entitySnake.endsWith('_list')` and only then strip it; or validate the resolved path exists (active discovery already does this — the fallback should only fire when discovery found nothing, and then it should probe candidate dirs for the actual file).

## Impact

Blocks all entities whose snake name contains `_list` as a substring in a position that isn't the list-method suffix — here `UrlListing`/`TextListing`/`BarcodeListing` (the reference ZikZak listing family). Low-risk fix in one function used by presenter/DI/test generators.


## Comments

**coderabbitai** (2026-08-13T13:01:40Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#258 - fix: resolve all 42 test failures after zuraffa/zuraffa_flutter split (`#256`) [merged]
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
