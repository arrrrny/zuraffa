# Bug Assessment: [zfa tdd] SingleTestRunner cannot find single/suite templates in legacy frontmatter YAML format (zfa tdd run blocked)

- **Slug**: tdd-runner-legacy-frontmatter-template
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/681
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`SingleTestRunner.loadSingleTemplate()` and `loadSuiteTemplate()` (used by `zfa tdd verify-red`, `zfa tdd make`, and the full `zfa tdd run` cycle) cannot find the `single:` and `suite:` command templates when they are stored in the legacy YAML frontmatter format. Both `verify-red` and `make` fail immediately with `no 'single'/'suite' command template found` even though the profile file contains valid entries.

The problematic profile format has a YAML frontmatter block where `single:`/`suite:` live nested under `stacks:<label>:` (e.g. `stacks: dart: single: 'dart test -n "{name}"'`), with NO `## Keys (machine-readable)` block.

## Symptom

`zfa tdd verify-red` / `zfa tdd make` / `zfa tdd run` fail on any project whose `tdd-profile.md` was written by the auto-detected ecosystem format (nested `stacks:<label>:` frontmatter), even though the templates are present and valid.

## Reproduction

1. `zfa tdd init` on a pure Dart package.
2. A previous run of the TDD profile detector wrote `tdd-profile.md` with a `stacks:dart:single:` YAML structure.
3. Run `zfa tdd verify-red U1 --feature <feature>` or `zfa tdd run <feature>`.
4. Error: `no 'single' command template found in .specify/memory/tdd-profile.md`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:104-132` — `loadSingleTemplate` legacy frontmatter extraction (1b block).
- `lib/src/plugins/tdd/services/runner.dart:177-202` — `loadSuiteTemplate` legacy frontmatter extraction (1b block).
- The frontmatter regex uses `multiLine: true`, which breaks `^---\n` anchoring.

## Root Cause Hypothesis

The frontmatter extraction regex `RegExp(r'^---\n([\s\S]*?)\n---', multiLine: true)` is wrong: `multiLine: true` makes `^` match at the start of every line, so the non-greedy `([\s\S]*?)` stops at the FIRST `\n---` in the file (which appears inside the frontmatter body, e.g. after `detected_at: ...`) and captures only a prefix instead of the full frontmatter block. With only a prefix captured, the subsequent `single:`/`suite:` search inside the frontmatter fails, and the command throws.

Confidence: **high** — the regex semantics are deterministic and the fix is mechanical (swap `multiLine: true` → `dotAll: true`).

## Proposed Remediation

**Preferred**: Change the frontmatter extraction regex flag from `multiLine: true` to `dotAll: true` in both `loadSingleTemplate` and `loadSuiteTemplate`:

```dart
// Correct: dotAll (not multiLine) so ^ anchors to string start
final frontmatterBlock = RegExp(r'^---\n([\s\S]*?)\n---', dotAll: true).firstMatch(raw);
```

`dotAll: true` allows `.` to match `\n` while keeping `^` anchored to the actual string start, so the non-greedy `([\s\S]*?)` correctly spans the full frontmatter block until the closing `\n---`. The inner `single:`/`suite:` value matchers keep `multiLine: true` (they need `^` to match at every line *inside* the already-extracted frontmatter block).

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` (two regex flag swaps)

**Tests to add or update**:
- `zfa tdd verify-red` on a profile with nested `stacks:dart:single:` frontmatter → resolves the template (no throw).
- `zfa tdd make` / `zfa tdd run` on the same profile → resolves `suite:` and proceeds.
- Regression: `## Keys (machine-readable)` block format still resolves (no regression).
- Regression: human-facing `- Single test:` / `- Full suite` bullets still resolve.

## Risks & Considerations

- `dotAll: true` changes `.` semantics; the regex uses `[\s\S]` explicitly (not `.`), so behavior is unaffected except for the `^` anchoring, which is the intended fix.
- The inner value matchers use `multiLine: true` deliberately — do not change those.

## Open Questions

- None blocking.