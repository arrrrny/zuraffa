# Bug Issue: [build] lib/zuraffa.dart:1172 — StateMigrator ambiguous_export (two classes) + directive_after_declaration

- **Slug**: issue-234-lib-zuraffa-dart-1172-statemigrator-ambiguous-export-two-cla
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 234
- **URL**: https://github.com/arrrrny/zuraffa/issues/234
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6

## Body

## Summary

`lib/zuraffa.dart` has two compile errors at line 1172:

```
error - lib/zuraffa.dart:1172:1 - Directives must appear before any declarations - directive_after_declaration
error - lib/zuraffa.dart:1172:8 - The name 'StateMigrator' is defined in the libraries 'package:zuraffa/src/state/migration/state_migrator.dart' and 'package:zuraffa/src/migration/fixers/state_fixer.dart' - ambiguous_export
```

## Root cause

There are **two** `StateMigrator` classes:
- `lib/src/state/migration/state_migrator.dart:10` — `class StateMigrator` (v5→v6 state migration tool, has `inputDir`/`outputDir` required fields)
- `lib/src/migration/fixers/state_fixer.dart:8` — `class StateMigrator extends MigrationFixer` (the fixer variant with `migrate({findings, ...})`)

Both are exported through `lib/zuraffa.dart` → the exported name `StateMigrator` is ambiguous. Additionally, the `export` directive at line 1172 appears after declarations (the migration export block was placed in the wrong section), triggering `directive_after_declaration`.

## Fix

1. Resolve the name collision — either rename one (e.g. `StateFixer` for the `MigrationFixer` subclass) or `hide StateMigrator` on one export.
2. Move the misplaced `export` directive to the top of `lib/zuraffa.dart` with the other exports (fixes `directive_after_declaration`).

## Acceptance

- [ ] No `ambiguous_export` for `StateMigrator`
- [ ] No `directive_after_declaration` in `lib/zuraffa.dart`
- [ ] `lib/zuraffa.dart` compiles; downstream imports of either migrator resolve unambiguously

## Comments

**coderabbitai** (2026-08-04T03:46:40Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#191 - feat(compiler): Track 1.3 — Decorator-Driven Architecture (DDA) Foundation [merged]
arrrrny/zuraffa#197 - feat(graphql): Track 3.1 — graphql_core foundation package [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
arrrrny/zuraffa#216 - [v6] Track 5.3 — Migration Tooling: v5 to v6 Upgrade Path [merged]
arrrrny/zuraffa#226 - fix: remove export of nonexistent graphql/naming_utils.dart (`#222`) [open]
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
**arrrrny** (2026-08-04T03:48:54Z):

⚠️ Overlaps with **#223** (directive_after_declaration) and **#224** (StateMigrator ambiguous_export) — both are the two errors at `zuraffa.dart:1172`. This issue consolidates them into one root-cause issue (two `StateMigrator` classes). Recommend keeping the consolidated version or closing this as duplicate of #223+#224.
