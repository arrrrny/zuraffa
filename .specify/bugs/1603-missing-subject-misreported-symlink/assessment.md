# Bug Assessment: missing subject file misreported as 'points outside the project root' on symlinked roots (macOS)

- **Slug**: 1603-missing-subject-misreported-symlink
- **Created**: 2026-09-14T00:00:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1603
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd view` (and the sibling `make`/`compose`/`wire`/`func` paths) report a **missing** subject file as *"points outside the project root"* whenever the project root reaches the filesystem through a symlink that `Directory.resolveSymbolicLinks()` expands (macOS `/var/folders/...` → `/private/var/folders/...`). Found while verifying PR #1581 on macOS (Dart 3.13.3, Intel Mac). Issue: https://github.com/arrrrny/zuraffa/issues/1603

## Symptom

When a registry record points to a subject file that does not exist, and the project root path contains a symlink, the command reports "points outside the project root" instead of the correct "missing subject file" message.

## Reproduction

```bash
dart pub get --no-example
dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'
```

Expected: message contains 'missing subject file'. Actual: message contains 'points outside the project root'.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/view_command.dart` — canonicalization guard ("Compare CANONICAL forms" comment)
- `lib/src/plugins/tdd/commands/compose_command.dart` — same pattern
- `lib/src/plugins/tdd/commands/wire_command.dart` — same pattern
- `lib/src/plugins/tdd/commands/func_command.dart` — same pattern

## Root Cause Hypothesis

`File(subjectPath).resolveSymbolicLinks()` throws `FileSystemException` for a non-existent path, so the `on FileSystemException` fallback keeps the subject's **un-canonicalized** string, while `canonicalRoot` is fully canonicalized. On macOS, `/var/folders/...` canonicalizes to `/private/var/folders/...`, so the containment check `canonicalSubject.startsWith(canonicalRoot)` fails and the "outside the project root" branch wins before `subjectFile.exists()` is ever consulted. On Linux, `/tmp` is not a symlink, so the un-canonicalized path still passes containment — which is why Linux CI is green.

## Proposed Remediation

Canonicalize the containing directory (which exists) plus the basename when the subject file itself is missing:

```dart
final canonicalSubject = await File(subjectPath).exists()
    ? await File(subjectPath).resolveSymbolicLinks()
    : p.join(
        await Directory(p.dirname(subjectPath)).resolveSymbolicLinks(),
        p.basename(subjectPath),
      );
```

Apply the same fix to `view_command.dart`, `compose_command.dart`, `wire_command.dart`, `func_command.dart`. Add a regression case asserting the missing-file message when the fixture root resolves through a symlink.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Hard constraint: fix ONLY the canonicalization guard in the four command files; do NOT change verify gate semantics or the closure scan.
- Linux CI cannot reproduce the failure directly (`/tmp` is not a symlink); the regression test must create its own symlinked fixture root so it fails on Linux too.

## Open Questions

- None blocking: root cause, fix shape, and test strategy are all specified in the issue.
