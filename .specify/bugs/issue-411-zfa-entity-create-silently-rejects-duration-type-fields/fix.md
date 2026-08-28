# Bug Fix: zfa entity create: silently rejects Duration type fields

- **Slug**: issue-411-zfa-entity-create-silently-rejects-duration-type-fields
- **Fixed**: 2026-08-22
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`EntityUtils.extractEntityTypes` classified `Duration` as a custom entity/enum
reference because it was missing from the dart:core exclusion list and starts
with an uppercase letter. The #296 pre-write validator then found no
`duration/duration.dart` entity and no `enums/duration.dart`, so
`zfa entity create --field x:Duration` aborted with "field type(s) could not be
resolved" and wrote nothing. Added `Duration` to the exclusion list so it
behaves like `DateTime` (and matches `KnownTypes.dartTypes`, which already
excluded it).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/utils/entity_utils.dart` | modified | Added `'Duration'` to the non-entity type list in `extractEntityTypes`, with a comment referencing `KnownTypes.dartTypes` and issue #411. |
| `test/utils/entity_utils_test.dart` | added | New focused unit test for `extractEntityTypes`: `Duration` excluded (bare/nullable/inside `List`/`Map`), other primitives still excluded, genuine entity/enum references still extracted. |

## Diff Highlights

```dart
 'DateTime',
+// `Duration` is a dart:core type (already listed in
+// KnownTypes.dartTypes). Without it here, a field declared as
+// `x:Duration` was treated as a custom entity reference and
+// rejected by EntityTypeValidator (issue #411).
+'Duration',
 'Object',
```

## Tests Added or Updated

- `test/utils/entity_utils_test.dart` — 3 tests across two groups; the first
  locks the #411 behaviour, the others guard against over-widening the list.

## Local Verification

- `dart analyze lib` → no `error` lines.
- `dart test test/utils/entity_utils_test.dart` → `All tests passed!` (3 tests).

## Deviations from Assessment

- The assessment-suggested test in `test/utils/entity_type_validator_test.dart`
  was **not** added: that file imports `package:zorphy` for `FieldDefinition`,
  and the sibling `../zorphy` path checkout does not compile in this environment
  (`'ParameterElement' isn't a type.`), so the whole file fails to load.
  Coverage was placed on `EntityUtils` instead, which is the exact code changed
  and has no zorphy dependency.

## Follow-ups

- Other dart:core types that are still misclassified by the same heuristic
  (`Uri`, `num`, `BigInt`, `Set` type arguments) would fail identically. Left
  out of this fix to keep it minimal; worth a follow-up issue.
- The broken `../zorphy` path dependency blocks running the CLI end-to-end
  locally; unrelated to this fix.
