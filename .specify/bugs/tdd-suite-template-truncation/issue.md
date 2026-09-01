# Bug Issue: loadSuiteTemplate truncates multi-word unquoted commands to first word

- **Slug**: tdd-suite-template-truncation
- **Fetched**: 2026-09-01
- **Issue**: 726
- **URL**: https://github.com/arrrrny/zuraffa/issues/726
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

After the merged fix for #681, `SingleTestRunner.loadSuiteTemplate()` (and likely `loadSingleTemplate()` for unquoted values) returns only the first word of a multi-word command. The unquoted-value pattern `[^\s#]+` stops at the first whitespace, so a profile entry like `suite: dart test` is read as `suite: dart`, not `suite: dart test`.

This causes `zfa tdd make` to run `dart` (with no arguments) for the suite baseline, which prints the `dart` CLI help and exits 0 — `make` then refuses with "the suite baseline did not produce a usable snapshot" even though the project is a perfectly normal pure-Dart package.

## Steps to Reproduce

1. `zfa tdd init` on a pure Dart package (creates `tdd-profile.md` with the ecosystem-detected frontmatter format)
2. The profile has `suite: dart test` (unquoted, in the `stacks:dart:suite:` block)
3. Add a failing test (e.g. via `zfa tdd gen U1` + `zfa tdd verify-red U1`)
4. Run `zfa tdd make U1 --feature <feature>`
5. Output:
   ```
   zfa tdd make: behavior U1
      feature: <feature>
      test: .../test/tdd/u1_test.dart
      suite baseline: dart
      baseline exit: 0, failed: 0
   zfa tdd make: the suite baseline did not produce a usable snapshot. Refusing to generate without a trustworthy pre-run failure set.
   ```
6. Confirm: the suite template loaded as `dart` (one word) instead of `dart test` (two words)

## Expected Behavior

`loadSuiteTemplate()` should return `dart test` (the full command), not just `dart`. Then the suite baseline would actually run the test suite, see the failing U1 test, and produce a usable snapshot.

## Root Cause

**File**: `lib/src/plugins/tdd/services/runner.dart`

The merged fix for #681 uses this regex for unquoted values:
```dart
r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+))\s*$'''
```

The third alternative `[^\s#]+` matches "non-whitespace, non-comment" characters — i.e., a single word. So for `suite: dart test` (unquoted), the regex matches and group 3 captures only `dart`.

The pattern should be `[^\s#]+(?:\s+[^\s#]+)*` (one or more whitespace-separated words) to capture multi-word unquoted values.

Or more simply: relax the unquoted capture to allow whitespace within the line: `[^\n#]+` (everything until end of line or comment).

## Suggested Fix

In `lib/src/plugins/tdd/services/runner.dart`, change the unquoted alternative in both `loadSingleTemplate` and `loadSuiteTemplate` regexes from `[^\s#]+` to a pattern that allows whitespace within the line. The simplest fix is:

```dart
r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|(\S+(?:\s+\S+)*))\s*$'''
```

The new third alternative `\S+(?:\s+\S+)*` matches one or more whitespace-separated non-whitespace tokens, preserving the full command.

## Affected Versions

- The bug exists in the merged fix for #681 (zfa v6.1.0+)
- It affects any profile with unquoted multi-word commands (e.g. `suite: dart test`, `single: dart test -n "{name}"` if unquoted)

## Severity

high — `zfa tdd make` and `zfa tdd run` are completely blocked on packages with the ecosystem-detected profile format because the suite baseline never runs the real suite

## Comments

None.
