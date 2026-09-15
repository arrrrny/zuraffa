# Bug Fix: tdd-profile `single:` — unescape YAML quotes, reject unknown placeholders at load time

- **Slug**: 1535-tdd-profile-yaml-escape-placeholder
- **Fixed**: 2026-09-16
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md

## Summary

The `SingleTestRunner` profile loader now (1) unescapes YAML **double-quoted**
scalar escapes (`\"`, `\\`, the C0 escapes, and the `\x..`/`\u....`/`\U........`
hex forms) before placeholder normalization and substitution, and (2) rejects
unknown placeholder spellings (`<test name>`, `{test_name}`, …) at **load time**
with a `StateError` that names the accepted placeholders (`{file}`, `{name}`) and
the remedy. The fix is parser-only: certification logic, the red classifier, and
process spawning are untouched.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/runner.dart` | modified | `_matchQuotedScalar` now reports WHICH quote style matched (`value`, `doubleQuoted` record); new `_yamlUnescapeDoubleQuoted` + `_hexCodePointAt` implement the YAML 1.2 §5.7 double-quoted escape table; new `_prepareSingleScalar` / `_prepareFileScalar` / `_prepareSuiteScalar` post-process each extracted scalar (unescape → normalize → AC-2 placeholder validation for the `single:` lane and the `- Single test:` bullet lane); `_firstMatchValue` retained as a thin wrapper (issue #695 instance-method contract preserved) |
| `test/plugins/tdd/bug_1535_profile_template_parsing_test.dart` | added test suite | 9 behaviors: AC-1 ×3, AC-2 ×3, AC-3 ×1 (slow e2e), AC-4 ×2 |

## Diff Highlights

The quote style is captured at extraction time — only the double-quoted style
is escape-processed (single-quoted YAML has no backslash escapes, unquoted
keeps backslashes literal):

```dart
final single = _matchQuotedScalar(
  r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?: [^\s#]+)*))\s*$''',
  keysBlock.group(1)!,
);
if (single != null && single.value.trim().isNotEmpty) {
  return _prepareSingleScalar(
    single.value.trim(),
    doubleQuoted: single.doubleQuoted,   // only the " style is unescaped
    workingDirectory: workingDirectory,
    profilePath: profilePath,
  );
}
```

Load-time rejection (AC-2) runs AFTER legacy normalization, so `<path>` /
`<file>` / `<name>` stay accepted while unknown spellings fail fast with a
named remedy:

```dart
final unknown = <String>[];
for (final match in RegExp(r'\{[^{}]*\}|<[^<>]*>').allMatches(template)) {
  final token = match.group(0)!;
  if (token != '{file}' && token != '{name}' && !unknown.contains(token)) {
    unknown.add(token);
  }
}
if (unknown.isNotEmpty) {
  throw StateError(
    'zfa tdd verify-red: unknown placeholder ${unknown.join(', ')} in '
    'the `single:` command template of ... Accepted placeholders: '
    '{file}, {name} ... Rewrite the `single:` value with an accepted '
    'placeholder, then re-run.',
  );
}
```

## Tests Added or Updated

- `test/plugins/tdd/bug_1535_profile_template_parsing_test.dart`
  - "unescapes YAML double-quoted escapes in the Keys block single: value" — AC-1
  - "unescapes YAML double-quoted escapes in frontmatter single: value" — AC-1
  - "unescapes YAML double-quoted escapes in file:/suite: keys" — AC-1
  - "rejects unknown placeholder `<test name>` at load time naming accepted placeholders" — AC-2
  - "still accepts legacy `<file>`/`<name>` spellings in a double-quoted value" — AC-2 guard
  - "bullet path also rejects an unknown placeholder spelling" — AC-2
  - "certifies an honest red through the YAML-escaped double-quoted single: template" (tagged `slow`, real subprocess) — AC-3: testCount == 1, `RedClassification.assertion`
  - "returns the single-quoted form verbatim (no over-escaping)" — AC-4 guard
  - "keeps normalizing the legacy Single test bullet" — AC-4 guard

## Local Verification

- Commands run (all real, this session):
  - `dart pub get` → resolved clean (dependency_overrides removed)
  - `dart analyze lib/src/plugins/tdd/services/runner.dart test/plugins/tdd/bug_1535_profile_template_parsing_test.dart` → `No issues found!`
  - RED (fix stashed): `dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all` → `+2 -7: Some tests failed.` (every bug behavior red; only the two pre-existing-contract guards green)
  - GREEN (fix restored): same command → `00:09 +9: All tests passed!`
  - Regression: `dart test test/plugins/tdd/services/` → `+1120 -10` with all 10 failures verified pre-existing (identical with fix stashed); top-level runner suites → `+20: All tests passed!`
  - `dart format` on both changed files → `0 changed`
- See ./tdd/verification.md for the full gate audit.

## Deviations from Assessment

None. The remediation follows the assessment's proposed scope exactly
(parser-only; single-quoted/unquoted scalars untouched; validation after
normalization; bullet lane included). One implementation nuance worth noting:
`file:` and `suite:` keys get escape-unescaping but NOT the unknown-placeholder
rejection (the batched lane substitutes only `{file}` and the suite carries no
placeholders) — rejection where no classification depends on it would add no
safety, so the `single:` lane (plus its human-facing bullet) carries the AC-2
check.

## Follow-ups

- None required for this bug. (Related #1162 / #1259 / #1488 were not touched,
  per the hard constraint.)
