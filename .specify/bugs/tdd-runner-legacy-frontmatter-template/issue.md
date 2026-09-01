# Bug Issue: [zfa tdd] SingleTestRunner cannot find single/suite templates in legacy frontmatter YAML format (zfa tdd run blocked)

- **Slug**: tdd-runner-legacy-frontmatter-template
- **Fetched**: 2026-09-01
- **Issue**: 681
- **URL**: https://github.com/arrrrny/zuraffa/issues/681
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

`SingleTestRunner.loadSingleTemplate()` and `loadSuiteTemplate()` (used by `zfa tdd verify-red`, `zfa tdd make`, and the full `zfa tdd run` cycle) cannot find the `single:` and `suite:` command templates when they are stored in the legacy YAML frontmatter format. Both `verify-red` and `make` fail immediately with `no 'single'/'suite' command template found` even though the profile file contains valid entries.

## Steps to Reproduce

1. `zfa tdd init` on a pure Dart package
2. A previous run of the TDD profile detector wrote `tdd-profile.md` with a `stacks:dart:single:` YAML structure (auto-detected ecosystem format)
3. Run `zfa tdd verify-red U1 --feature <feature>` or `zfa tdd run <feature>`
4. Error: `no 'single' command template found in .specify/memory/tdd-profile.md`

## Existing Profile Structure (the problematic format)

The profile has a YAML frontmatter block that contains `single:` and `suite:` inside a nested structure:

```yaml
---
detected_at: 2b966f2
ecosystems: [dart]
default: dart
stacks:
  dart:
    cwd: .
    runner: "package:test (^1.24.0)"
    single: 'dart test -n "{name}"'
    file: dart test {file}
    suite: dart test
    coverage: 'dart test --coverage=coverage'
    ...
---
```

Note: there is NO `## Keys (machine-readable)` block in this format — the keys live entirely in the YAML frontmatter under `stacks:<label>:`.

## Expected Behavior

`SingleTestRunner` should find the `single:` template whether it is:
1. In the `## Keys (machine-readable)` block (the current implementation handles this ✅)
2. In the legacy YAML frontmatter at top-level (`single: '...'`)
3. In the legacy YAML frontmatter at `stacks:<label>:single:` (nested under ecosystem label)

Same for `suite:`.

## Root Cause

**File**: `lib/src/plugins/tdd/services/runner.dart`

`SingleTestRunner` only looks for the `single:` key in:
1. The `## Keys (machine-readable)` YAML code block
2. A human-facing `- Single test: \`...\`` bullet

The legacy frontmatter format (where `single:` lives at `stacks:dart:single:`) is not recognized. The frontmatter extraction logic (when added) uses `multiLine: true` on the regex that captures the frontmatter body — this breaks the `^---\n` anchor at the start, causing the regex to capture only a small prefix of the frontmatter instead of the full block.

The bug pattern is:
```dart
final frontmatterBlock = RegExp(
  r'^---\n([\s\S]*?)\n---',
  multiLine: true,  // BUG: makes ^ match at every line start
).firstMatch(raw);
```

With `multiLine: true`, `^` matches at the start of every line — so `^---\n` matches the opening `---` at position 0, then `([\s\S]*?)` is non-greedy and stops at the **first** `\n---` in the file (which appears on line 3: `detected_at: 2b966f2\n...\n---`), capturing only `detected_at: 2b966f2` instead of the full frontmatter.

## Attempted Fix (local zuraffa, not committed)

1. Added a `1b. Legacy frontmatter YAML block` section to both `loadSingleTemplate` and `loadSuiteTemplate` with a frontmatter extraction regex
2. **Bug in the fix**: `multiLine: true` on the frontmatter regex caused it to capture only a partial prefix. The fix is to use `dotAll: true` (or no flag — default) so `.` matches newlines but `^` stays anchored to the actual string start
3. The correct regex is: `RegExp(r'^---\n([\s\S]*?)\n---')` with **no `multiLine: true`** (default `^` anchors to string start, `\n---` still found correctly)
4. Or equivalently: `RegExp(r'^---\n([\s\S]*?)\n---', dotAll: true)` (dotAll allows `.` to match `\n`, `^` stays at string start)

## Suggested Fix

In `lib/src/plugins/tdd/services/runner.dart`:

For `loadSingleTemplate` and `loadSuiteTemplate`, after the Keys block check fails, extract the frontmatter block with:
```dart
// Correct: dotAll (not multiLine) so ^ anchors to string start
final frontmatterBlock = RegExp(r'^---\n([\s\S]*?)\n---', dotAll: true).firstMatch(raw);
```

Then search for `single:` / `suite:` under both top-level and `stacks:<label>:` nesting:
```dart
// Top-level first
var found = RegExp(r"""^\s*single:\s*['"](.+)['"]""", multiLine: true).firstMatch(frontmatter);
```

## Severity

medium — blocks `zfa tdd run` on any project whose profile uses the auto-detected ecosystem format