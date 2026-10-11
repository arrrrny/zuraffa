# Bug Spec: a MISSING subject file is misreported as 'points outside the project root' on symlinked roots

- **Slug**: 1603-missing-subject-misreported-symlink
- **Source assessment**: ./assessment.md
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1603
- **TDD feature**: this directory
- **TDD mode**: ON

## Problem (reproduced)

`tdd view` (and the sibling subject-guard sites in `compose`, `wire`, `func`)
canonicalize the project root but keep the subject's RAW string when
`File(subjectPath).resolveSymbolicLinks()` throws for a missing file. When the
project root reaches the filesystem through a symlink (macOS
`/var/folders/...` → `/private/var/folders/...`), the containment check
compares a raw subject path against a canonicalized root, never matches, and
the "points outside the project root" branch wins before the
`subjectFile.exists()` check can run. A *missing* subject is therefore
misreported as *outside the project root*. Linux CI is green because `/tmp`
is not a symlink.

Repro (macOS): `dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'`
fails with `Expected: contains 'missing subject file'`.

## Acceptance Criteria (the fixed behavior)

Each criterion is observable from the public CLI surface and is the target a
failing test will pin.

- **AC1** — Given a fixture whose project root is reached through a symlink
  and a registry record whose subject file does not exist, `zfa tdd view`
  exits non-zero and reports the record points to a **missing subject file**
  (never "points outside the project root").
- **AC2** — The same symlinked-root scenario for `zfa tdd func` reports the
  **missing subject file** branch, including when the recorded subject path
  travels the canonical side of the symlink while `--project` travels the raw
  side.
- **AC3** — The same symlinked-root scenario for `zfa tdd compose` reports the
  **missing subject file** branch (guard must keep existing-file behavior:
  an in-root subject symlink targeting outside the project is still refused).
- **AC4** — The same symlinked-root scenario for `zfa tdd wire` reports the
  **missing subject file** branch (guard must keep existing-file behavior:
  an in-root subject symlink targeting outside the project is still refused).
- **AC5** — An existing subject under a symlinked root still resolves: the
  canonical containment check must not begin refusing subjects that were
  previously accepted (no behavior flip for the green path).

## Constraints

- Fix ONLY the canonicalization guard in the four command files
  (`view_command.dart`, `compose_command.dart`, `wire_command.dart`,
  `func_command.dart`). Do NOT change verify gate semantics or the closure
  scan.
- Canonicalize a missing subject through its nearest EXISTING ancestor
  directory and re-append the remaining segments (the containing directory
  exists, the file does not).
