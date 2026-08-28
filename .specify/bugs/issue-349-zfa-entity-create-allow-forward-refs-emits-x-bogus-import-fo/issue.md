# Bug Issue: zfa entity create --allow-forward-refs emits $X + bogus import for external (non-entity) types — plugin model migration gap

- **Slug**: issue-349-zfa-entity-create-allow-forward-refs-emits-x-bogus-import-fo
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 349
- **URL**: https://github.com/arrrrny/zuraffa/issues/349
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, enhancement, task, v6, zuraffa_core, zfa_cli

## Body

## Context
Migrating zikzak_inappwebview models to Zorphy entities via `zfa entity create` (per the vendure-flutter-sdk rewrite pattern). The plugin models reference EXISTING external classes that live OUTSIDE lib/src/domain/entities (here: `WebUri`, the plugin's URI wrapper at lib/src/web_uri.dart). There is no zfa way to reference such a type.

## Repro (minimal)
In any package with zorphy_annotation + build_runner wired:
```
zfa entity create -n JsAlertRequest --kind=value_object --allow-forward-refs --field url:WebUri? --field message:String?
```

## Expected
The field references the existing external class `WebUri?` and the generated file imports it correctly (the caller provides the import or a supported way to declare one).

## Actual
```dart
// lib/src/domain/entities/js_alert_request/js_alert_request.dart
import '../web_uri/web_uri.dart';   // does NOT exist (no such entity dir)

abstract class $JsAlertRequest {
  $WebUri? get url;   // wrong: `$`-prefixed, implies a WebUri entity to be generated
  String? get message;
}
```
The type string I passed (`WebUri?`) is rewritten to `$WebUri?` and `_fixEntityImports` emits an import for `../web_uri/web_uri.dart` which does not exist, so the generated source does not compile without manual post-processing. `--allow-forward-refs` is documented for cyclic schemas where the referenced entity WILL be created later — but there is no escape hatch for types that are never entities (external/existing classes).

## Suggested fix
Add a way to declare a field type as an external reference (e.g. a `!Type` suffix or `:external=` option) that: (1) keeps the type name un-prefixed, (2) skips the on-disk validation, and (3) does not emit a guessed import (or emits an import the user can provide via a flag).

## Workaround used (for the record)
Manually fixing the generated source (drop `$`, correct the import) — the same class of post-generation fix the vendure migration used for zuraffa#272 cross-file references. Documented in zikzak_inappwebview/PROGRESS.md.

## Comments

**coderabbitai** (2026-08-15T09:36:28Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#293 - fix(zfa make): toggle field type uses Field<Entity, dynamic> not EntityFields (`#292`) [merged]
arrrrny/zuraffa#297 - fix(zfa entity create): validate field types before writing, abort on unresolvable enum/entity type (`#296`) [merged]
arrrrny/zuraffa#316 - test(entity create): lock in `#308` --allow-forward-refs regression suite + help docs [merged]
arrrrny/zuraffa#322 - fix(zfa): entity identity contract — autoId + ValueObject, loud no-id error (`#307`) [merged]
arrrrny/zuraffa#339 - fix(zfa view create): hide colliding Flutter symbols from material import (`#337`) [merged]
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
