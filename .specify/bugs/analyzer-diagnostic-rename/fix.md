# Fix report — analyzer 14.6.0 renamed `undefined_getter`

- **Slug**: analyzer-diagnostic-rename
- **Assessment**: ./assessment.md
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1980
- **Branch**: fix/issue-1980
- **Status**: applied

## What changed

1. **`test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`**
   — the U-1685-G2 assertion now accepts both spellings of the analyzer's
   missing-member diagnostic (`undefined_getter`, `undefined_instance_member_read`).
   The gate's meaning is unchanged: the historical snippet still must NOT
   compile, and the reported diagnostic must still be the missing-member one.

2. **`lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart`** and
   **`lib/src/plugins/tdd/services/ci_referee/review_snippets.dart`** — the doc
   comments no longer present `undefined_getter` as the spelling the analyzer
   emits. On analyzer >= 14.6.0 that code can no longer be produced, so the
   comments described a value that never appears in
   `SnippetValidationIssue.code`.

## Deviations from Assessment

None — the preferred remediation in the assessment was applied as proposed.

## Known follow-ups (deliberately out of scope)

- The assertion still pins literal diagnostic spellings, so the next analyzer
  rename reproduces this breakage. The root fix (commit `pubspec.lock`, or pin
  the analyzer's upper bound) is explicitly deferred by issue #1980.
- `undefined_getter` was REMOVED (not renamed-and-kept) in analyzer 14.6.0, so
  that branch only fires while the package resolves analyzer <= 14.5.x — still
  possible under `analyzer: ^14.4.0`. Drop it in the same change that moves
  the analyzer floor to 14.6.0.

## Test evidence

- `dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart` → green
- `dart analyze test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart` → no issues
