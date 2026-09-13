# Bug Fix: a MISSING subject file is not "outside the project root" on symlinked roots

- **Slug**: missing-subject-symlink-root
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md (verification written by the bug-test step)
- **Branch**: `fix/missing-subject-symlink-root`

## Summary

`zfa tdd view` canonicalized the project root but, for a *missing* subject,
fell back to the **raw** subject path — so on macOS (where the temp root
`/var/folders/...` canonicalizes to `/private/var/folders/...`) the
outside-root guard won before the missing-file check could run. The fix
canonicalizes a missing subject through its nearest **EXISTING** ancestor
(resolve that ancestor, re-append the missing segments), the same shape
`wire_command.dart` carries since `c1e287da` (PR #1516 review). A new
regression pin makes the symlinked-root case deterministic on every platform.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/view_command.dart` | modified | The `canonicalSubject` catch block now calls the new private static `_canonicalizeMissingPath` instead of taking the raw path; the helper is copied verbatim in shape from `wire_command.dart` (`c1e287da`). |
| `test/plugins/tdd/commands/view_command_test.dart` | added tests | U-V11 (symlinked root → missing-file refusal, deterministic cross-platform), U-V12 (genuine-outside refusal unchanged — the FR-002 guard); `runView` gained a `project` override; header doc updated. |

## Diff Highlights

`lib/src/plugins/tdd/commands/view_command.dart`:

```dart
} on FileSystemException {
  // A missing subject file (the U-V3 artifact case) has nothing to
  // resolve: canonicalize through its nearest EXISTING ancestor and
  // re-append the remaining segments. Taking the raw path here made
  // a symlinked temp root (`/var/folders` → `/private/var/folders`
  // on macOS) read the project's own recorded path as "outside the
  // project root" — the wrong refusal branch (issue #1603; the same
  // fix wire carries since pull/1516 review, c1e287da).
  canonicalSubject = await _canonicalizeMissingPath(subjectPath);
}
```

New helper (same body as `wire_command.dart:800`):

```dart
static Future<String> _canonicalizeMissingPath(String path) async {
  var dir = Directory(p.dirname(path));
  final tail = <String>[p.basename(path)];
  while (true) {
    try {
      final resolved = await dir.resolveSymbolicLinks();
      return p.joinAll([resolved, ...tail.reversed]);
    } on FileSystemException {
      final parent = dir.parent;
      if (parent.path == dir.path) return path;
      tail.add(p.basename(dir.path));
      dir = parent;
    }
  }
}
```

## Tests Added or Updated

- `view_command_test.dart` U-V11 — a missing subject under an explicit sibling
  symlink is the missing-file refusal, never "outside the project root" (RED
  pre-fix with the exact issue symptom; GREEN post-fix).
- `view_command_test.dart` U-V12 — a recorded subject that genuinely resolves
  outside the root is still refused as outside-root (FR-002 guard; green
  pre-fix and post-fix).
- U-V3 (pre-existing) — the original macOS red: now green.

## Local Verification

- `dart test test/plugins/tdd/commands/view_command_test.dart -n "U-V1[12]"` (pre-fix) → `+1 -1`: U-V11 red with `points outside the project root`, U-V12 guard green. Evidence: `tdd/cycle-log.md`.
- `dart test test/plugins/tdd/commands/view_command_test.dart` (post-fix) → `12/12 All tests passed!` including U-V3.
- `dart test` over the sibling view surface (`bug_1141_view_audit`, `bug_965_view_i18n_generation`, `bug_1141_login_ui_regeneration`, `spec_1142_adaptive_layout`) → `29/29 All tests passed!`
- `dart analyze lib/src/plugins/tdd/commands/view_command.dart test/plugins/tdd/commands/view_command_test.dart` → `No issues found!`
- `dart format` on both touched files → `0 changed`.

## Deviations from Assessment

- The assessment (from issue #1603) said the same broken shape was "duplicated
  in compose_command.dart, wire_command.dart and func_command.dart". On the
  current tree only `view_command.dart` still had it:
  - `wire_command.dart` was already fixed (`c1e287da`, PR #1516 review) — the
    precedent copied here.
  - `compose_command.dart` checks `subjectFile.exists()` **before** the
    outside-root comparison, so it already prints the missing-file message.
  - `func_command.dart` compares the raw forms of the same normalized base —
    a relative recorded path (the portable `#1397` form the registry stores)
    can never trip its outside-root branch.
  Scope was therefore kept to `view_command.dart` (the failing surface).

## Follow-ups

- None required. (Optional: a shared `canonicalizeMissingPath` utility could
  replace the two private copies in view/wire — deliberately NOT done here to
  keep the change surgical.)
