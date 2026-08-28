# Bug Issue: [tests] migration_test.dart — StateMigrator API mismatch (6 errors, downstream of #234)

- **Slug**: issue-235-migration-test-dart-statemigrator-api-mismatch-6-errors-down
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 235
- **URL**: https://github.com/arrrrny/zuraffa/issues/235
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6

## Body

## Summary

`test/migration_test.dart` fails to compile — 6 analyzer errors from 2 test sites that construct `StateMigrator` with the wrong API:

```
error - test/migration_test.dart:441:24 - The named parameter 'inputDir' is required, but there's no corresponding argument - missing_required_argument
error - test/migration_test.dart:441:24 - The named parameter 'outputDir' is required, but there's no corresponding argument - missing_required_argument
error - test/migration_test.dart:442:37 - The method 'migrate' isn't defined for the type 'StateMigrator' - undefined_method
error - test/migration_test.dart:485:24 - The named parameter 'inputDir' is required, but there's no corresponding argument - missing_required_argument
error - test/migration_test.dart:485:24 - The named parameter 'outputDir' is required, but there's no corresponding argument - missing_required_argument
error - test/migration_test.dart:486:37 - The method 'migrate' isn't defined for the type 'StateMigrator' - undefined_method
```

## Root cause

The tests construct `StateMigrator()` with no args and call `migrate(findings: [...])` — that is the **`MigrationFixer` variant** (`lib/src/migration/fixers/state_fixer.dart`, which has `migrate({findings})`). But due to the `ambiguous_export` in `lib/zuraffa.dart` (issue #234), the import resolves to the **other** `StateMigrator` — the v5→v6 tool (`lib/src/state/migration/state_migrator.dart`) which requires `inputDir`/`outputDir` and has no `migrate` method.

So this is downstream breakage of the naming collision. Once #234 is resolved (rename one class or fix the export), these tests will likely resolve correctly — but they should also be checked for the intended target.

## Fix

Resolve the root cause in #234, then verify:
- `test/migration_test.dart:441` and `:485` construct the intended `StateMigrator` (the MigrationFixer one with `migrate({findings})`)
- Or, if the tests target the v5→v6 tool, update them to pass `inputDir`/`outputDir` and use its API

## Acceptance

- [ ] The 6 `missing_required_argument` / `undefined_method` errors are gone
- [ ] `test/migration_test.dart` compiles and the migration tests pass

## Comments

**coderabbitai** (2026-08-04T03:46:58Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->

<details>
<summary>⚠️ Possible Duplicate Issue(s)</summary>

- https://github.com/arrrrny/zuraffa/issues/224
</details>
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#193 - feat(state): Track 2.1 — Fragmented Signal Slices [merged]
arrrrny/zuraffa#194 - feat(state): Track 2.2 — Dual-Layer State Boundary (DomainState vs ViewState) [merged]
arrrrny/zuraffa#197 - feat(graphql): Track 3.1 — graphql_core foundation package [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
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
