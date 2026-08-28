# Bug Issue: [bug] Directive appears after declaration in zuraffa.dart (line 1172)

- **Slug**: issue-223-directive-appears-after-declaration-in-zuraffa-dart-line-117
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 223
- **URL**: https://github.com/arrrrny/zuraffa/issues/223
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6

## Body

## Description

`dart analyze lib/zuraffa.dart` reports:

```
error - zuraffa.dart:1172:1 - Directives must appear before any declarations. Try moving the directive before any declarations.
```

Line 1172 in `lib/zuraffa.dart`:
```dart
// v5 -> v6 migration tooling
export \x27src/migration/migration.dart\x27;
```

An `export` directive appears after non-directive declarations (likely a class or function defined earlier in the barrel file). Dart requires all `import`/`export` directives to precede any declarations.

## Impact

- Breaks `dart analyze` on the package entrypoint
- Downstream consumers hit a compile error

## Suggested Fix

Move the `export src/migration/migration.dart;` line up into the directive block at the top of `zuraffa.dart`, grouped with the other migration-related exports. The comment "v5 -> v6 migration tooling"\nshould also be relocated with it.

## Environment

- Dart 3.11.0 / Flutter 3.41.1
- Discovered during Track 6.3 development (PR #220)


## Comments

**coderabbitai** (2026-08-03T20:30:02Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#216 - [v6] Track 5.3 — Migration Tooling: v5 to v6 Upgrade Path [merged]
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
