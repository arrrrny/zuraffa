# Bug Issue: [gql] gql_fixer.dart:118 regex syntax error — analyzer cannot parse the triple-quote pattern

- **Slug**: issue-233-gql-fixer-dart-118-regex-syntax-error-analyzer-cannot-parse
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 233
- **URL**: https://github.com/arrrrny/zuraffa/issues/233
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6

## Body

## Summary

The gql migration fixer has a regex syntax error at `lib/src/migration/fixers/gql_fixer.dart:118` → 1 analyzer error + 1 info:

```
error - lib/src/migration/fixers/gql_fixer.dart:118:51 - Expected to find ')' - expected_token
info   - lib/src/migration/fixers/gql_fixer.dart:118:35 - Invalid regular expression syntax - valid_regexps
```

## Root cause

Line 118:

```dart
final quotePattern = RegExp(r'^\s*(r)?\s*(\'\'\'|""")');
```

The raw string `r'...'` contains `\'` escape sequences inside a single-quoted raw string along with `"""`. The analyzer cannot parse the `(r)?\s*(\'\'\'|""")` group correctly — the `\'` in a raw single-quoted string is a literal backslash-quote, and combined with the `"""` it produces an unbalanced token stream → `Expected to find ')'`.

## Fix

Use a non-raw string with proper escapes, or a double-quoted raw string that doesn't need the `\'`:

```dart
final quotePattern = RegExp("^\\s*(r)?\\s*('''|\"\"\")");
```

Or construct with explicit alternation that the parser handles cleanly. Verify the regex actually matches `gql('''...''')` and `gql("""...""")` call sites (this fixer scans for `gql(` calls with triple-quoted string args).

## Acceptance

- [ ] `gql_fixer.dart:118` parses cleanly (`expected_token` error gone)
- [ ] `valid_regexps` info gone
- [ ] The fixer still correctly detects `gql('''...''')` / `gql("""...""")` documents (existing gql_fixer tests pass)

## Comments

**coderabbitai** (2026-08-04T03:46:04Z):

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
