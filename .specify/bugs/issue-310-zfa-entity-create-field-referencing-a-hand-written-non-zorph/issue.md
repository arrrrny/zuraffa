# Bug Issue: zfa entity create: field referencing a hand-written (non-Zorphy) class emits  -> InvalidType in concrete class

- **Slug**: issue-310-zfa-entity-create-field-referencing-a-hand-written-non-zorph
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 310
- **URL**: https://github.com/arrrrny/zuraffa/issues/310
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6, zuraffa_core, zfa_cli

## Body

## Expected

`zfa entity create` should generate correct code when an entity references a
**hand-written (non-Zorphy) class** in another file — e.g. a sealed union
dispatcher like Vendure's `SearchResultPrice` (a plain `sealed class` with a
`runtimeType`-dispatch `fromJson`, kept as SDK glue). The generated field should
reference the plain type (`SearchResultPrice`), which resolves via the import.

## Actual

`FieldNormalizer._determinePrefix` returns `$` for ANY field type whose entity
directory exists, without checking whether the target file actually declares a
Zorphy abstract (`abstract class $X`). For a plain/sealed target it emits
`$SearchResultPrice get price;` in the source. The analyzer cannot resolve the
undefined identifier `$SearchResultPrice`, so the generated concrete class gets
`final InvalidType price;` and `zfa build` fails in json_serializable:

```
E json_serializable on .../search_result/search_result.dart:
  Could not generate `fromJson` code for `price`.
  To support the type `InvalidType` you can: ...
  final InvalidType price;
```

## Repro

```
# glue: lib/src/domain/entities/search_result_price/search_result_price.dart
sealed class SearchResultPrice { ... }   # plain class, NO `abstract class $SearchResultPrice`

zfa entity create -n SearchResult --field price:SearchResultPrice? --allow-forward-refs
zfa build
# -> E json_serializable: final InvalidType price;
```

## Impact

Blocks the vendure-flutter-sdk zfa-driven rewrite: `SearchResult.price` /
`priceWithTax` reference the hand-written `SearchResultPrice` sealed dispatcher
(1 entity, 2 fields). Mixed projects (generated Zorphy entities + hand-written
glue classes in the same tree) cannot build. Reported per the Zuraffa Obstacle
Protocol rather than hand-editing the generated entity.

## Suggested fix

In `zorphy/lib/src/cli/services/field_normalizer.dart` `_determinePrefix`:
- `abstract class $$X` in the target file → `$$`
- `abstract class $X` in the target file → `$`
- otherwise (plain/sealed hand-written class) → `''` (emit the plain type;
  `ImportResolver` already adds the entity import when the directory exists).


## Comments

**coderabbitai** (2026-08-13T18:58:26Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
arrrrny/zuraffa#286 - fix: zfa make canonical command (printed by setup) produces non-compiling code: missing data repo impl + missing orchestrator usecase [merged]
arrrrny/zuraffa#293 - fix(zfa make): toggle field type uses Field<Entity, dynamic> not EntityFields (`#292`) [merged]
arrrrny/zuraffa#295 - fix(zfa make): entity-aware id-field resolution + mock datasource methods default (`#294`) [merged]
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
