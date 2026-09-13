# Bug Issue: missing subject file misreported as 'points outside the project root' on symlinked roots (macOS)

- **Slug**: 1603-missing-subject-misreported-symlink
- **Fetched**: 2026-09-14T00:00:00Z
- **Issue**: 1603
- **URL**: https://github.com/arrrrny/zuraffa/issues/1603
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

## Summary

`zfa tdd view` (and the sibling `make`/`compose`/`wire`/`func` paths) report a **missing**
subject file as *"points outside the project root"* whenever the project root reaches the
filesystem through a symlink that `Directory.resolveSymbolicLinks()` expands.

Found while verifying PR #1581 on macOS (Dart 3.13.3, macOS on an Intel Mac).

## Repro

```bash
git clone https://github.com/arrrrny/zuraffa && cd zuraffa
dart pub get --no-example
dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'
```

## Expected

```
zfa tdd view: the registry record for behavior "A-001" points to a missing subject file at
"lib/a_001_subject.dart". Run `zfa tdd gen A-001` to restore its artifacts.
```

## Actual

```
zfa tdd view: the registry record for behavior "A-001" points outside the project root at
"lib/a_001_subject.dart". Run `zfa tdd gen A-001` to restore its artifacts.
```

Test result: `Expected: contains 'missing subject file'` — `Which: does not contain
'missing subject file'`.

## Root cause

`lib/src/plugins/tdd/commands/view_command.dart` (the guard starting at the
"Compare CANONICAL forms" comment) canonicalizes the subject with:

```dart
String canonicalSubject;
try {
  canonicalSubject = await File(subjectPath).resolveSymbolicLinks();
} on FileSystemException {
  canonicalSubject = subjectPath;   // <-- the MISSING-file path
}
```

`resolveSymbolicLinks()` throws for a non-existent path, so a *missing* subject keeps its
**un-canonicalized** string while `canonicalRoot` is the **canonicalized** root. On macOS a
test fixture root under `/var/folders/...` canonicalizes to `/private/var/folders/...`, so
the two never compare equal and the "outside the project root" branch wins before the
`subjectFile.exists()` check can ever run. On Linux (`/tmp` is not a symlink) the un-canonical
path is still within the root and the correct branch is reached, which is why the suite is
green on Linux CI.

The same shape is duplicated in `compose_command.dart`, `wire_command.dart` and
`func_command.dart`.

## Suggested fix

Canonicalize the *containing directory* (which does exist) plus the basename, or compare both
forms — canonical and raw — against the root, then fall through to the missing-file branch:

```dart
final canonicalSubject = await File(subjectPath).exists()
    ? await File(subjectPath).resolveSymbolicLinks()
    : p.join(
        await Directory(p.dirname(subjectPath)).resolveSymbolicLinks(),
        p.basename(subjectPath),
      );
```

Add a regression case asserting the missing-file message when the fixture root resolves
through a symlink (on macOS the existing U-V3 already covers it).

## Comments

None.
