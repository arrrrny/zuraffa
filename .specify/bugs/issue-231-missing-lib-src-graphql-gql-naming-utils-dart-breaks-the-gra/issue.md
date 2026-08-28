# Bug Issue: [graphql] Missing lib/src/graphql/gql/naming_utils.dart breaks the GraphQL plugin (4 analyzer errors)

- **Slug**: issue-231-missing-lib-src-graphql-gql-naming-utils-dart-breaks-the-gra
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 231
- **URL**: https://github.com/arrrrny/zuraffa/issues/231
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6

## Body

## Summary

The GraphQL plugin is broken at compile time: `lib/src/graphql/gql/naming_utils.dart` does not exist, but it is imported/exported in 3 places → 4 analyzer errors. `dart analyze` reports:

```
error - lib/src/graphql/codegen/datasource_generator.dart:5:8 - Target of URI doesn't exist: '../gql/naming_utils.dart' - uri_does_not_exist
error - lib/src/graphql/codegen/datasource_generator.dart:573:12 - Undefined name 'NamingUtils' - undefined_identifier
error - lib/src/graphql/gql/documents_dart_generator.dart:6:8 - Target of URI doesn't exist: 'naming_utils.dart' - uri_does_not_exist
error - lib/src/graphql/gql/documents_dart_generator.dart:48:23 - Undefined name 'NamingUtils' - undefined_identifier
error - lib/zuraffa.dart:516:8 - Target of URI doesn't exist: 'src/graphql/gql/naming_utils.dart' - uri_does_not_exist
```

## Root cause

`lib/src/graphql/gql/` currently contains only `documents_dart_generator.dart` and `graphql_document_builder.dart`. The `NamingUtils` class (referenced at `datasource_generator.dart:573` and `documents_dart_generator.dart:48`, exported via `lib/zuraffa.dart:516`) was never created — likely lost in a refactor/merge. The GraphQL codegen pipeline cannot compile until it exists.

## Fix

Create `lib/src/graphql/gql/naming_utils.dart` with the `NamingUtils` API that both generators expect. Check the usages:
- `datasource_generator.dart:573` — `NamingUtils` usage
- `documents_dart_generator.dart:48` — `NamingUtils` usage
- `lib/zuraffa.dart:516` — `export 'src/graphql/gql/naming_utils.dart';`

## Acceptance

- [ ] `lib/src/graphql/gql/naming_utils.dart` exists with the expected `NamingUtils` API
- [ ] The 5 errors above are gone from `dart analyze`
- [ ] GraphQL datasource + documents generators compile

## Comments

**coderabbitai** (2026-08-04T03:44:52Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->

<details>
<summary>⚠️ Possible Duplicate Issue(s)</summary>

- https://github.com/arrrrny/zuraffa/issues/222
</details>
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#197 - feat(graphql): Track 3.1 — graphql_core foundation package [merged]
arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
arrrrny/zuraffa#199 - feat(graphql): Track 3.3 — GraphQL Client Runtime & Subscription Support [merged]
arrrrny/zuraffa#206 - feat(graphql): Track 3.5 — gql Plugin: Real .graphql File Generation & Datasource Integration [merged]
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

⚠️ Overlaps with **#222** ("[bug] zuraffa.dart exports nonexistent file src/graphql/gql/naming_utils.dart") — same root cause: `lib/src/graphql/gql/naming_utils.dart` does not exist. This issue adds the **complete** analyzer error list (5 errors incl. the 2 generators' `undefined_identifier`) + acceptance criteria. Recommend consolidating: keep one, close the other as duplicate. Fix is the same either way (recreate the file or remove the export).
