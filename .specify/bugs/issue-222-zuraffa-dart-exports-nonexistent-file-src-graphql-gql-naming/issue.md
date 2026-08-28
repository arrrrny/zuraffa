# Bug Issue: [bug] zuraffa.dart exports nonexistent file src/graphql/gql/naming_utils.dart

- **Slug**: issue-222-zuraffa-dart-exports-nonexistent-file-src-graphql-gql-naming
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 222
- **URL**: https://github.com/arrrrny/zuraffa/issues/222
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6

## Body

## Description

`dart analyze lib/zuraffa.dart` reports a compile-time error:

```
error - zuraffa.dart:516:8 - Target of URI does not exist: \x27src/graphql/gql/naming_utils.dart\x27
```

Line 516 in `lib/zuraffa.dart`:
```dart
// NamingUtils — shared naming utilities for consistent variable naming.
export \x27src/graphql/gql/naming_utils.dart\x27;
```

The file `lib/src/graphql/gql/naming_utils.dart` does not exist in the repository. This was likely deleted or renamed during a prior refactoring (GraphQL work was deprioritized per the ROADMAP "GraphQL decision" item) but the barrel export was not cleaned up.

## Impact

- Breaks `dart analyze` on the package entrypoint
- Downstream consumers cannot compile without errors
- CI/static analysis fails on any PR that touches the barrel file

## Suggested Fix

Either:
1. Remove the export line if the file is no longer needed
2. Re-create the file if it was accidentally deleted
3. Check if `NamingUtils` was moved to another path and update the export URI

## Environment

- Dart 3.11.0 / Flutter 3.41.1
- Discovered during Track 6.3 development (PR #220)


## Comments

**coderabbitai** (2026-08-03T20:29:47Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#206 - feat(graphql): Track 3.5 — gql Plugin: Real .graphql File Generation & Datasource Integration [merged]
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
