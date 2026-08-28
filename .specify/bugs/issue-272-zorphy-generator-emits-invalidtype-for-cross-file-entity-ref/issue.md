# Bug Issue: zorphy generator emits InvalidType for cross-file entity references

- **Slug**: issue-272-zorphy-generator-emits-invalidtype-for-cross-file-entity-ref
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 272
- **URL**: https://github.com/arrrrny/zuraffa/issues/272
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6, zuraffa_core

## Body

## Expected
A @Zorphy entity that references another entity in a DIFFERENT file (e.g. `B get b;` in a.dart, B defined in b.dart) should generate the referenced type in a.zorphy.dart — with either a direct import ('b.dart') or a barrel re-export ('entities.dart').

## Actual
The generator emits `final InvalidType b;` in the .zorphy.dart output for BOTH import styles. Minimal repro (vendure toolchain — pubspec/pubspec.lock/build.yaml copied from vendure-flutter-sdk; files under lib/src/domain/entities/ref/):

- b.dart: @Zorphy(generateJson: true) abstract class $B { String get id; }
- a.dart: imports b (case 2: 'b.dart'; case 1: '../entities.dart'), part 'a.g.dart' + 'a.zorphy.dart', @Zorphy abstract class $A { String get id; B get b; }
- entities.dart: exports both

Result (both cases): 'final InvalidType b;' + 'InvalidType? b' in a.zorphy.dart; build_runner reports the failure. Repo: /workspace/zrep4 in the Daytona sandbox (SID a2674551-b576-4a82-bd86-5c28a844ee2e) — run `bash /workspace/zrep4.sh`.

## Impact
vendure-flutter-sdk rewrite (arrrrny/vendure-flutter-sdk #6): 235 hand-written Zorphy entities with heavy cross-references — 65 of 123 entity dirs emit InvalidType. .g.dart (json_serializable) generation works fine; only the .zorphy.dart parts fail on cross-file refs.

## Suggested fix
Resolve referenced types via analyzer elements (not name strings) and emit the needed imports in the part file — or document that cross-file references require the referenced type to be resolvable in the source library (it IS resolvable here, so this is a generator bug).

## Comments

**coderabbitai** (2026-08-05T15:26:14Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
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
**arrrrny** (2026-08-13T17:28:02Z):

Verified FIXED on current toolchain (2026-08-13): zuraffa development a8f3354 + zorphy development 85de507. Spike: `zfa entity create` for Address with a Country field + `zfa build` generates correct cross-file output — `final Country country;` in address.zorphy.dart, `Country.fromJson` in address.g.dart, **zero InvalidType occurrences** across all entities (incl. Map<String,dynamic>, List<X>, nullable, enum-typed, dynamic fields). Closing this issue unblocks the vendure-flutter-sdk zfa-driven rewrite for the cross-reference path. Remaining blocker for that rewrite is #303 (custom JSON wire names).
