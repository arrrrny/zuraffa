## Summary

`zfa tdd view` canonicalized the project root but fell back to the **raw**
subject path when the subject file was missing. On a symlinked root (macOS:
`/var/folders/...` canonicalizes to `/private/var/folders/...`) the
un-canonicalized subject compared as outside the root, so the outside-root
refusal fired before the missing-file check could run — the issue's exact
symptom: a missing subject reported as *"points outside the project root"*
instead of *"points to a missing subject file"*.

The fix canonicalizes a missing subject through its **nearest EXISTING
ancestor** (resolve that ancestor through symlinks, re-append the missing
segments) — the same shape `wire_command.dart` carries since `c1e287da`
(PR #1516 review). `view_command.dart` was the one sibling left unfixed.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/view_command.dart` | modified | the `canonicalSubject` catch calls the new private static `_canonicalizeMissingPath` instead of taking the raw path |
| `test/plugins/tdd/commands/view_command_test.dart` | added tests | **U-V11** — missing subject under an explicit sibling symlink is the missing-file refusal (deterministic on Linux CI too); **U-V12** — the genuine outside-root refusal is unchanged (guard); `runView` gained a `project` override |
| `.specify/bugs/missing-subject-symlink-root/` | added | assessment / spec / fix / test records + TDD test list, cycle log, verification report |

## Local Verification

- Pre-fix RED: `dart test test/plugins/tdd/commands/view_command_test.dart -n "U-V1[12]"` → `+1 -1` — U-V11 fails with `points outside the project root` (the issue's symptom), U-V12 guard green.
- Post-fix: `dart test test/plugins/tdd/commands/view_command_test.dart` → `00:51 +12: All tests passed!` — including **U-V3**, the original macOS red from the issue.
- Issue's exact repro, post-fix: `dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'` → `00:04 +1: All tests passed!`
- Sibling view surface (`bug_1141_view_audit`, `bug_965_view_i18n_generation`, `bug_1141_login_ui_regeneration`, `spec_1142_adaptive_layout`) → `00:38 +29: All tests passed!`
- Mutation sampling (no mutation tool wired): identity canonicalization (the pre-fix shape) killed by U-V11; outside-root guard disabled killed by U-V12. Both reverted.
- `dart analyze` on both changed files → `No issues found!`; `dart format --set-exit-if-changed lib test` → 0 changed.
- TDD verification verdict: **PASS** (`tdd/verification.md`).

Assessment: `.specify/bugs/missing-subject-symlink-root/assessment.md`

## Scope note

The issue suspected the same shape in `compose_`, `wire_`, and `func_command.dart`.
On the current tree only `view_command.dart` still had it: `wire_command.dart` was
already fixed (`c1e287da`); `compose_command.dart` checks the missing file *before*
the root comparison; `func_command.dart` compares raw forms of the same normalized
base (relative recorded paths never trip it). Scope kept to the failing surface.

Closes #1603.
