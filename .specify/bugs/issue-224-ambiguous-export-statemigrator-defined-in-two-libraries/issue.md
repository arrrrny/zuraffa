# Bug Issue: [bug] Ambiguous export: StateMigrator defined in two libraries

- **Slug**: issue-224-ambiguous-export-statemigrator-defined-in-two-libraries
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 224
- **URL**: https://github.com/arrrrny/zuraffa/issues/224
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6

## Body

## Description

`dart analyze lib/zuraffa.dart` reports:

```
error - zuraffa.dart:1172:8 - The name StateMigrator is defined in the libraries:
  - package:zuraffa/src/state/migration/state_migrator.dart
  - package:zuraffa/src/migration/fixers/state_fixer.dart
```

Both libraries are barrel-exported from `lib/zuraffa.dart`, and both define a class named `StateMigrator`. Dart cannot resolve which one a consumer means when they import `package:zuraffa/zuraffa.dart`.

## Files

- `lib/src/state/migration/state_migrator.dart` — original location
- `lib/src/migration/fixers/state_fixer.dart` — likely a v5→v6 migration duplicate

## Impact

- `dart analyze` fails on the package entrypoint
- Downstream consumers get an `ambiguous_export` error
- CI/static analysis is broken for the entire repo

## Suggested Fix

1. If `state_fixer.dart` is the canonical v6 version, hide `StateMigrator` in the old export:
   ```dart
   export src/state/migration/state_migrator.dart hide StateMigrator;
   ```
2. Or rename one of them (e.g. `StateMigratorV5` / `StateMigratorFixer`) to disambiguate
3. Or remove the stale v5 export entirely if it is no longer needed

## Environment

- Dart 3.11.0 / Flutter 3.41.1
- Discovered during Track 6.3 development (PR #220)


## Comments

**coderabbitai** (2026-08-03T20:30:26Z):

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
