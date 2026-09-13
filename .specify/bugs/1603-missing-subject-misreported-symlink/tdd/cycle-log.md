# Cycle Log: 1603-missing-subject-misreported-symlink

## Cycle: U-1603a (red)

- behavior: U-1603a
- kind: red
- classification: assertionFailure
- criterion: AC1
- test: test/plugins/tdd/commands/view_command_test.dart --plain-name "U-1603a"
- command: `dart test test/plugins/tdd/commands/view_command_test.dart --plain-name "U-1603a"`
- exit: 1
- at: 2026-09-14 (pre-fix, Linux with symlink-aliased fixture root)
- output:
```
Expected: contains 'missing subject file'
  Which: does not contain 'missing subject file'

Failing tests:
  test/plugins/tdd/commands/view_command_test.dart: U-1603a
```
- reading: the aliased root reproduces macOS `/var` → `/private/var`
  exactly — `canonicalRoot` canonicalizes, the missing subject keeps its
  raw string, containment fails, and the "outside the project root"
  branch wins before `subjectFile.exists()` runs. Same signature as the
  issue's U-V3 failure report.

## Cycle: U-1603c (red)

- behavior: U-1603c
- kind: red
- classification: assertionFailure
- criterion: AC2
- test: test/plugins/tdd/commands/func_command_test.dart --plain-name "U-1603c"
- command: `dart test test/plugins/tdd/commands/func_command_test.dart --plain-name "U-1603c"`
- exit: 1
- at: 2026-09-14 (pre-fix, Linux with symlink-aliased fixture root + canonical-recorded subject)
- output:
```
Expected: contains 'missing subject file'
  Which: does not contain 'missing subject file'

Failing tests:
  test/plugins/tdd/commands/func_command_test.dart: U-1603c
```
- reading: func's guard compares RAW `normalizedCwd` against the subject
  path; a record written on the canonical side of the root symlink
  (Directory.current is canonicalized on macOS) fails raw containment and
  misreports "outside the project root" for the project's own subject.

## Cycle: U-1603b / U-1603d / U-1603e (green pre-fix — regression pins)

- behavior: U-1603b, U-1603d, U-1603e
- kind: pin (green before fix, must stay green after)
- classification: none (guards already correct)
- criterion: AC5 (view green path), AC3 (compose), AC4 (wire)
- command: `dart test <file> --plain-name "U-1603b|U-1603d|U-1603e"`
- exit: 0 for all three
- at: 2026-09-14 (pre-fix)
- reading:
  - U-1603d: compose checks `subjectFile.exists()` BEFORE canonicalizing,
    so a missing subject already reaches the correct "missing subject
    file" branch through the symlinked root.
  - U-1603e: wire canonicalizes a missing subject through its nearest
    EXISTING ancestor (`_canonicalizeMissingPath`, PR #1516 review fix).
  - U-1603b: existing subjects resolve through the root symlink and are
    processed — the fix must not flip this.
