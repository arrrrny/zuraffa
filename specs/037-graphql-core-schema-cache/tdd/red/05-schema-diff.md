# Red Evidence — Schema diff engine

**Test file**: `test/graphql/schema_diff_test.dart`
**Behaviors**: B13 — identical → no changes; B14 — removed type; B15 — removed
field; B16 — nullability change; B17 — added required field; B18 — added
optional field; B19 — enum add/remove; B20 — 9/9 accuracy vs Vendure fixture;
plus defensive base-type-change case
**Spec**: FR-003, FR-004, SC-002, US-2 scenarios 1–5

## First-run output (before implementation)

```
$ dart test test/graphql/schema_diff_test.dart

  test/graphql/schema_diff_test.dart:5:8: Error: Error when reading
  'lib/src/graphql/diff/schema_diff.dart': No such file or directory
  test/graphql/schema_diff_test.dart:27:20: Error: Undefined name
  'SchemaDiffer'.
  test/graphql/schema_diff_test.dart:35:26: Error: Undefined name
  'ChangeKind'.
  test/graphql/schema_diff_test.dart:39:38: Error: Undefined name
  'ChangeSeverity'.
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no diff engine existed anywhere in the repo
(`grep -r "SchemaDiffer" lib/` → no matches before this branch).
