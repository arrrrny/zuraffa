# Test: missing subject misreported as 'points outside the project root' on symlinked roots (#1603)

- **Slug**: 1603-missing-subject-misreported-symlink
- **Suite**: `test/plugins/tdd/commands/view_command_test.dart`,
  `test/plugins/tdd/commands/func_command_test.dart`,
  `test/plugins/tdd/commands/compose_command_test.dart`,
  `test/plugins/tdd/wire_command_test.dart`
  (fast tier, in-process `CliRunner` against a `TddFixture` — the suites'
  existing conventions)

## Validation of the acceptance criteria

| AC (spec.md) | Scenario | Test | Result |
| --- | --- | --- | --- |
| AC1 | missing subject, fixture root reached through a symlink, `zfa tdd view` | U-1603a (`view_command_test.dart`) | PASS — reports "missing subject file", asserts "outside the project root" never appears |
| AC2 | missing subject recorded on the CANONICAL side of the root symlink, `--project` on the raw side, `zfa tdd func` | U-1603c (`func_command_test.dart`) | PASS — reports "missing subject file" + names `zfa tdd gen B-001` |
| AC3 | missing subject under a symlinked root, `zfa tdd compose` | U-1603d (`compose_command_test.dart`) | PASS (pin — compose's exists-first guard already correct; stays green post-fix) |
| AC4 | missing subject under a symlinked root, `zfa tdd wire` | U-1603e (`wire_command_test.dart`) | PASS (pin — wire carries the pull/1516-review `_canonicalizeMissingPath` guard; stays green post-fix) |
| AC5 | EXISTING subject under a symlinked root is still processed | U-1603b (`view_command_test.dart`) | PASS — exit 0, subject rewritten, no refusal |

## Original issue pins (unchanged, all green post-fix)

- U-V3 (missing subject, `view`) — `view_command_test.dart`
- U-W3 (missing subject, `wire`) — `wire_command_test.dart`
- U-F5 (missing subject, `func`) — `func_command_test.dart`

## Reproduction technique

The macOS condition is reproduced deterministically on Linux: the fixture
root is a real temp directory, a symlink alias of it is created, and the
ALIAS is passed as `--project`. The raw (alias) cwd then canonicalizes to a
different prefix — byte-for-byte the shape macOS gets for free from
`/var/folders` → `/private/var/folders`. Pre-fix, U-1603a and U-1603c fail
with the issue's exact reported signature
(`Which: does not contain 'missing subject file'`); post-fix, all green.
Windows skips via the same `onPlatform` convention as the existing U12
symlink test.

## Verification audit

`_tdd/verification.md` records the full audit: verdict **PASS**, 5/5
behaviors PROVEN, 5/5 acceptance criteria covered, deliberate-mutant
sampling 2/2 killed (each fix site reverted to its pre-fix shape and the
pinning test re-run red), fast-tier TDD scope 2431 passed with the only 10
failures byte-identical to a clean master worktree's pre-existing
e2e-lane failures, `dart analyze` clean on changed files, `dart format`
clean.
