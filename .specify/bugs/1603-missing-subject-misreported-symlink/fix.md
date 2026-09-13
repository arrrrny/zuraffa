# Fix Report: missing subject misreported as 'points outside the project root' on symlinked roots (#1603)

- **Slug**: 1603-missing-subject-misreported-symlink
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1603
- **Branch**: fix/1603-missing-subject-misreported-symlink
- **TDD artifacts**: `tdd/test-list.md`, `tdd/cycle-log.md`, `tdd/verification.md`

## Root Cause (confirmed)

The subject-containment guard in `view_command.dart` canonicalized the
project root but kept the subject's **raw string** when
`File(subjectPath).resolveSymbolicLinks()` threw for a missing file:

```dart
} on FileSystemException {
  canonicalSubject = subjectPath;   // raw, un-canonicalized
}
```

On macOS (`/var/folders/...` → `/private/var/folders/...`) the raw subject
path is never within the canonicalized root, so the "points outside the
project root" branch won before `subjectFile.exists()` could classify the
record as a **missing subject file**. Linux CI is green because `/tmp` is
not a symlink, so the raw path still passes containment.

The same *shape* was audited in all four guard sites:

| File | State on master before this fix | Action |
|------|--------------------------------|--------|
| `view_command.dart` | **buggy** — raw fallback (`canonicalSubject = subjectPath`) | **fixed** |
| `func_command.dart` | **unprotected** — guard compared two RAW paths (`normalizedCwd` vs `subjectPath`); any canonical-side record vs raw-side `--project` (or vice versa) misfires | **fixed** (canonicalized both sides) |
| `wire_command.dart` | already fixed by pull/1516 review (`_canonicalizeMissingPath`) | regression pin added (`U-1603e`) |
| `compose_command.dart` | already immune — `exists()` is checked BEFORE canonicalization, missing → correct branch | regression pin added (`U-1603d`) |

## Remediation (applied)

The guard now canonicalizes a missing subject through its nearest EXISTING
ancestor directory and re-appends the remaining segments — the containing
directory exists even when the file does not:

```dart
String canonicalSubject;
try {
  canonicalSubject = await File(subjectPath).resolveSymbolicLinks();
} on FileSystemException {
  canonicalSubject = await _canonicalizeMissingPath(subjectPath);
}
```

with

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

This mirrors wire's pull/1516-review guard verbatim (same helper shape,
same walk-up-until-existing discipline).

### Changed files (code)

1. `lib/src/plugins/tdd/commands/view_command.dart`
   - `FileSystemException` fallback now routes through the new private
     `_canonicalizeMissingPath` helper instead of keeping the raw string.
   - Added the private static `_canonicalizeMissingPath` helper.
2. `lib/src/plugins/tdd/commands/func_command.dart`
   - The guard previously compared two RAW paths; it now canonicalizes
     BOTH sides (`canonicalRoot` via `Directory.resolveSymbolicLinks()`,
     `canonicalSubject` via resolve-or-`_canonicalizeMissingPath`).
   - Added the same private static `_canonicalizeMissingPath` helper.

### Changed files (tests)

3. `test/plugins/tdd/commands/view_command_test.dart`
   - `U-1603a` (RED→GREEN): missing subject + symlinked root reports
     "missing subject file", never "outside the project root".
   - `U-1603b` (pin): an existing subject under a symlinked root is still
     processed (no green-path flip).
4. `test/plugins/tdd/commands/func_command_test.dart`
   - `U-1603c` (RED→GREEN): missing subject recorded on the CANONICAL side
     of the root symlink, `--project` on the raw side → "missing subject
     file" (this is macOS's native shape; reproduced deterministically on
     Linux via a symlink-aliased fixture root).
5. `test/plugins/tdd/commands/compose_command_test.dart`
   - `U-1603d` (pin): missing subject + symlinked root → "missing subject
     file" (proves compose's exists-first guard already satisfies AC3).
6. `test/plugins/tdd/wire_command_test.dart`
   - `U-1603e` (pin): missing subject + symlinked root → "missing subject
     file" (proves wire's `_canonicalizeMissingPath` guard satisfies AC4).

### Reproduction technique (works on Linux CI)

The tests create the fixture root as a REAL directory, alias it with a
symlink, and pass the **alias** as `--project`. The raw (alias) cwd then
canonicalizes to a different prefix — byte-for-byte the shape macOS gets
for free from `/var/folders` → `/private/var/folders`. Windows skips (no
privilege-free symlinks), matching the existing U12 symlink test
convention.

## Constraints honored

- Fix touches ONLY the canonicalization guard in the command files — no
  verify gate semantics, no closure scan, no registry/record shape
  changes, no shared-utility refactor.
- One PR per bug, branch `fix/1603-missing-subject-misreported-symlink`.

## Post-rebase addendum (honest timeline)

While this branch was in flight, PR #1606 (`fix/missing-subject-symlink-root`)
merged the SAME view_command fix — independently converged on the identical
`_canonicalizeMissingPath` walk-up helper and fallback routing (both mirror
wire's c1e287da pattern), with equivalent regression tests (U-V11/U-V12/
U-V13) — and closed issue #1603. On rebase onto that master:

- `view_command.dart` now carries master's copy of the identical fix (this
  branch no longer deltas that file; conflict resolved to master's version).
- This branch's remaining code delta is exactly the unique value:
  `func_command.dart` hardening (canonical-side record vs raw-side
  `--project`) and the compose/wire symlinked-root regression pins
  (U-1603d/U-1603e) plus the view green-path pin (U-1603b).
- Post-rebase gates re-run: the four affected suites 57/57 (includes
  U-V11/12/13 + U-1603a..e), `dart analyze` on the delta — No issues
  found, `dart format` — 0 changed.
