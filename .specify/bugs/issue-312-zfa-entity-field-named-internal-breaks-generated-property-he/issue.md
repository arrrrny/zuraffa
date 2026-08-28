# Bug Issue: zfa entity: field named 'internal' breaks generated property helpers (meta.internal collision)

- **Slug**: issue-312-zfa-entity-field-named-internal-breaks-generated-property-he
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 312
- **URL**: https://github.com/arrrrny/zuraffa/issues/312
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, zuraffa_core, zfa_cli

## Body

## Expected

`zfa entity create -n BooleanCustomFieldConfig --field internal:bool? ...` should
generate valid Dart. The nullable-field property helpers (`hasX`, `noX`,
`XRequired`) must reference the instance field unambiguously.

## Actual

The generated `XRequired`/`hasX`/`noX` helpers for a field named **`internal`**
break at analyze time. Every Zorphy entity library imports
`package:zorphy_annotation/zorphy_annotation.dart`, which re-exports
`package:meta/meta.dart` — and meta exports a top-level **`internal`** const
(an `Internal` object). Inside the generated extension, bare `internal` resolves
to that top-level const (type `Object`) instead of the instance field:

```
E boolean_custom_field_config.zorphy.dart:
  A value of type 'Object' can't be returned from the function 'internalRequired'
  because it has a return type of 'bool'.    return internal ?? (throw StateError(...));
```

Minimal repro (works without the meta import, fails with it):
```dart
import 'package:meta/meta.dart';
class A { final bool? internal; A({this.internal}); }
extension E on A { bool get internalRequired => internal ?? (throw StateError('x')); }
// error: A value of type 'Object' can't be returned from a function with return type 'bool'.
```

## Impact

Blocks the vendure-flutter-sdk zfa-driven rewrite: the Vendure schema has
`CustomFieldConfig.internal` (9 generated entities: Boolean/DateTime/Float/Int/
LocaleString/LocaleText/Relation/String/TextCustomFieldConfig). Reported per the
Zuraffa Obstacle Protocol rather than renaming the field (wire contract) or
hand-editing the generated helpers.

## Suggested fix

In the property-helper generation, reference the instance field explicitly as
`this.internal` (and `this.internal`/`this.internal` in `hasX`/`noX`) so the
expression resolves to the field regardless of top-level name collisions — or
suffix helper names when the field name collides with a library-exported name.


## Comments

**coderabbitai** (2026-08-13T19:10:26Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#226 - fix: remove export of nonexistent graphql/naming_utils.dart (`#222`) [open]
arrrrny/zuraffa#228 - fix: disambiguate StateMigrator ambiguous export (`#224`) [merged]
arrrrny/zuraffa#255 - fix: address review comments on `#254` [merged]
arrrrny/zuraffa#293 - fix(zfa make): toggle field type uses Field<Entity, dynamic> not EntityFields (`#292`) [merged]
arrrrny/zuraffa#297 - fix(zfa entity create): validate field types before writing, abort on unresolvable enum/entity type (`#296`) [merged]
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
**arrrrny** (2026-08-13T19:16:01Z):

Fixed: zorphy development c4704f1 — property helpers now emit 'this.<field>' so a field named 'internal' resolves to the instance member (verified: BooleanCustomFieldConfig{internal:bool?} builds + analyzes clean).
