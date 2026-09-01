# Bug Issue: [zfa tdd init] TddProfileWriter rejects valid non-Flutter profiles on re-run (exact-content comparison too strict)

- **Slug**: issue-680-tdd-profile-writer-exact-comparison-2
- **Fetched**: 2026-09-01T14:12:00Z
- **Issue**: 680
- **URL**: https://github.com/arrrrny/zuraffa/issues/680
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

`TddProfileWriter` (used by `zfa tdd init`) throws `StateError` and exits non-zero when an existing `tdd-profile.md` has valid-but-different content — even when the project kind (Dart vs Flutter) matches exactly. This blocks idempotent re-runs of `zfa tdd init` on any project that already has a profile.

The comparison is an exact byte-equality check of the generated template vs. the existing file. But the generated template is not identical to what the tool actually needs: it uses hardcoded preset values (e.g. `runner: dart`, `single: 'dart test {file} --name "{name}"`) that differ from valid custom profiles (e.g. `runner: "package:test (^1.24.0)"`, `single: 'dart test -n "{name}"'`).

## Steps to Reproduce

1. `zfa tdd init` runs successfully once on a pure Dart package — creates `tdd-profile.md` with the preset content
2. The profile is later enriched with richer metadata (e.g. ecosystem detector adds `stacks: dart: { runner: "package:test (^1.24.0)", ... }`)
3. Run `zfa tdd init` again
4. Error: `Bad state: tdd-profile.md already exists at ... with different content; refusing to overwrite. Delete the file first if you want to regenerate.`

## Expected Behavior

For non-Flutter projects, `TddProfileWriter` should accept any existing `tdd-profile.md` that uses a Dart runner — different metadata content should not trigger a rejection. The profile is already valid; overwriting it with a less-detailed template would lose information.

## Root Cause

**File**: `lib/src/cli/writers/tdd/tdd_profile_writer.dart`

`TddProfileWriter.write()` does:
```dart
if (existing.trim() == content.trim()) {
  return null; // identical — accept
}
throw StateError('...refusing to overwrite...'); // any difference — reject
```

The comparison is exact byte-equality against the generated template. But the generated template's `single:` value is `'dart test {file} --name "{name}"'` while the existing file has `'dart test -n "{name}"'` — both are valid, neither is wrong. The rejection is overly strict.

## Attempted Fixes (not committed — local zuraffa only)

1. **Lenient frontmatter check**: detect non-Flutter runners and skip the exact-match guard. Problem: the existing profile uses a nested `stacks:dart:single:` YAML structure, and the regex used `multiLine: true` on the outer frontmatter block which broke `^---\n` matching.

2. **Frontmatter regex `multiLine: true` bug**: `RegExp(r'^---\n([\s\S]*?)\n---', multiLine: true)` — `multiLine: true` makes `^` match at every line start, so `^---\n` matches the `---` at the start of the frontmatter delimiter but then `([\s\S]*?)` is non-greedy and stops at the first `\n---\n` it finds, capturing only `detected_at: ...` instead of the full block.

3. **The correct approach**: For pure Dart projects (where `isFlutterProfile == false`), if the existing file already has a non-Flutter runner in the frontmatter, accept it as valid regardless of exact content match. The Flutter-vs-Dart flavor conflict is the only meaningful check.

## Suggested Fix

In `TddProfileWriter.write()`, before the exact-content comparison:
- Extract the runner value from the existing frontmatter
- If `existing.runner is non-Flutter AND we are writing a Dart profile` → return `null` (accept the existing profile as-is)
- Only throw when the existing runner is Flutter but we're targeting Dart (genuine flavor conflict), or when the content is identical (no-op)

Also fix the frontmatter extraction regex to use `multiLine: false` (the default), or use `dotAll: true` instead to allow `.` to match newlines while keeping `^` anchored to the actual file start.

## Severity

medium — blocks idempotent `zfa tdd init` re-runs on any project with a custom/auto-detected profile

## Comments

None.
