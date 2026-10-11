# Bug Assessment: missing subject file misreported as 'points outside the project root' on symlinked roots

- **Slug**: missing-subject-symlink-root
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1603
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

Loaded from issue #1603 (arrrrny). `zfa tdd view` (and the sibling `make`/`compose`/`wire`/
`func` paths) report a **missing** subject file as *"points outside the project root"*
whenever the project root reaches the filesystem through a symlink that
`Directory.resolveSymbolicLinks()` expands (e.g. macOS `/var/folders` → `/private/var/folders`).

## Symptom

For a registry record whose subject file is missing, `zfa tdd view` prints
"points outside the project root" instead of the expected "points to a missing subject file"
message when the fixture root resolves through a symlink.

## Reproduction

```bash
git clone https://github.com/arrrrny/zuraffa && cd zuraffa
dart pub get --no-example
dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'
```

Expected: `contains 'missing subject file'`.
Actual: `does not contain 'missing subject file'` (message says "points outside the project
root").

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/view_command.dart` — the guard at the "Compare CANONICAL
  forms" comment.
- Same shape duplicated in `compose_command.dart`, `wire_command.dart`, `func_command.dart`.

## Root Cause Hypothesis

`File(subjectPath).resolveSymbolicLinks()` throws for a non-existent path, so the catch
falls back to the **un-canonicalized** `subjectPath`, while `canonicalRoot` is the
**canonicalized** root. On macOS the fixture root under `/var/folders/...` canonicalizes to
`/private/var/folders/...`, so the two never compare equal and the "outside the project root"
branch wins before the `subjectFile.exists()` check can run. Linux is green because `/tmp`
is not a symlink.

## Proposed Remediation

Canonicalize the containing directory (which does exist) plus the basename when the subject
file is missing; otherwise canonicalize the file itself. Or compare both canonical and raw
forms against the root, then fall through to the missing-file branch:

```dart
final canonicalSubject = await File(subjectPath).exists()
    ? await File(subjectPath).resolveSymbolicLinks()
    : p.join(
        await Directory(p.dirname(subjectPath)).resolveSymbolicLinks(),
        p.basename(subjectPath),
      );
```

Add a regression case asserting the missing-file message when the fixture root resolves
through a symlink.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- The same misreport pattern is duplicated in 4 sibling command paths — fixing only
  `view_command.dart` leaves the siblings inconsistent (fix step decides scope).

## Open Questions

- Do all four sibling commands share a helper that can take the canonicalization fix once?
