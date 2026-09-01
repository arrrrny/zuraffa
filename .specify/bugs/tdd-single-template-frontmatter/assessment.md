# Bug Assessment: [zfa tdd] SingleTestRunner cannot find single/suite templates in legacy frontmatter YAML format (zfa tdd run blocked)

- **Slug**: tdd-single-template-frontmatter
- **Created**: 2026-09-01T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/681
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`SingleTestRunner.loadSingleTemplate()` and `loadSuiteTemplate()` in `lib/src/plugins/tdd/services/runner.dart` cannot find `single:` and `suite:` command templates when stored in the legacy YAML frontmatter format. The error `no 'single' command template found` is thrown even when valid entries exist in the profile file. This blocks `zfa tdd verify-red`, `zfa tdd make`, and the full `zfa tdd run` cycle. Reported by arrrwny (Ahmet TOK); severity: high.

## Symptom

Running `zfa tdd verify-red U1 --feature <feature>` or `zfa tdd run <feature>` on a project whose `.specify/memory/tdd-profile.md` uses the legacy YAML frontmatter format (auto-detected by `zfa tdd init`) produces: `no 'single' command template found in .specify/memory/tdd-profile.md`.

## Reproduction

1. Run `zfa tdd init` on a pure Dart package (the TDD profile detector writes `tdd-profile.md` with `stacks:dart:single:` YAML structure, as shown in the `tdd-stack-profile.md` template).
2. Run `zfa tdd verify-red U1 --feature <feature>` or `zfa tdd run <feature>`.
3. Observe: `zfa tdd verify-red: no 'single' command template found in .specify/memory/tdd-profile.md`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:83–116` (`loadSingleTemplate`) — searches only the `## Keys (machine-readable)` YAML block and the human-facing `## Commands` bullet; does not check legacy frontmatter.
- `lib/src/plugins/tdd/services/runner.dart:126–161` (`loadSuiteTemplate`) — same limitation for `suite:`.
- `lib/src/plugins/tdd/commands/verify_red_command.dart:143` — calls `loadSingleTemplate`.
- `lib/src/plugins/tdd/commands/make_command.dart:196–197` — calls both `loadSingleTemplate` and `loadSuiteTemplate`.

## Root Cause Hypothesis

**High confidence.** `loadSingleTemplate` and `loadSuiteTemplate` only handle two profile formats:
1. The `## Keys (machine-readable)` YAML code block (`single:` at top level).
2. The human-facing `- Single test: \`...\`` bullet in `## Commands`.

The legacy format written by the TDD profile detector (as documented in the `tdd-stack-profile.md` template) stores keys in YAML frontmatter with nesting: `stacks:<label>:single:` and `stacks:<label>:suite:`. This nesting path is never searched, so the template lookup always fails for profiles in this format.

The issue also notes a secondary bug: a prior attempted fix used `multiLine: true` on the frontmatter regex (`^---\n([\s\S]*?)\n---`), which causes `^` to match at every line start instead of the string start. With `multiLine: true`, the non-greedy group `([\s\S]*?)` stops at the first `\n---` inside the YAML (e.g., `detected_at: ...\n---\n`), capturing only a prefix instead of the full frontmatter. The correct flag is `dotAll: true` (or no flag at all, since `dotAll` defaults to false and allows `.` to match newlines when explicitly set).

## Proposed Remediation

**Preferred**: Add a step 1b to both `loadSingleTemplate` and `loadSuiteTemplate` in `lib/src/plugins/tdd/services/runner.dart` that extracts the YAML frontmatter block and searches for `single:` / `suite:` at both top-level and `stacks:<label>:` nesting. Insert this after the Keys block check and before the bullet check.

The correct frontmatter regex uses `dotAll: true` (not `multiLine: true`):
```dart
// Correct: dotAll (not multiLine) so ^ anchors to string start
final frontmatterBlock = RegExp(r'^---\n([\s\S]*?)\n---', dotAll: true).firstMatch(raw);
```

Then search for the key at top-level first, then nested under `stacks:<label>:`:
```dart
// Top-level first
var found = RegExp(r"""^\s*single:\s*['"](.+)['"]""", multiLine: true).firstMatch(frontmatter);
// Then nested (only if top-level not found)
if (found == null) {
  found = RegExp(r"""^\s+single:\s*['"](.+)['"]""", multiLine: true).firstMatch(frontmatter);
}
```

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` — add frontmatter extraction and search in both methods.

**Tests to add or update**:
- Add unit tests in `test/plugins/tdd/` covering:
  - Profile with only legacy frontmatter format (`single:` under `stacks:dart:`).
  - Profile with both frontmatter and Keys block (Keys block should win).
  - Edge case: frontmatter regex correctly handles `dotAll` vs `multiLine`.

## Risks & Considerations

- Adding a new resolution step to both methods may slightly increase profile lookup time, but the cost is negligible for a small file read.
- The fix must not break the existing Keys block resolution path.
- The `dotAll` vs `multiLine` distinction is subtle; a regression test specifically covering the frontmatter regex is essential to prevent the mistake from recurring.

## Open Questions

- [RESOLVED: The `stacks:<label>:single:` nesting path is confirmed by the `tdd-stack-profile.md` template (lines 101–131).]
- [RESOLVED: The current codebase has no frontmatter extraction logic in `runner.dart` — the issue describes a prior attempted fix that introduced this, but it is not in the current codebase.]
- [NEEDS CLARIFICATION: Whether the attempted fix was reverted or never committed — relevant to understanding the full history but not to the remediation.]
