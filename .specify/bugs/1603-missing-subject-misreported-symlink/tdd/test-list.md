# Test List: 1603-missing-subject-misreported-symlink

feature: 1603-missing-subject-misreported-symlink
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U-1603a | a missing subject under a SYMLINKED project root reports "missing subject file" (never "points outside the project root") — `zfa tdd view` | AC1 | unit | DONE | test/plugins/tdd/commands/view_command_test.dart |
| U-1603b | an existing subject under a symlinked root still resolves and processes (no behavior flip for the green path) — `zfa tdd view` | AC5 | unit | DONE | test/plugins/tdd/commands/view_command_test.dart |
| U-1603c | a missing subject whose recorded path travels the canonical side while `--project` travels the raw side reports "missing subject file" — `zfa tdd func` | AC2 | unit | DONE | test/plugins/tdd/commands/func_command_test.dart |
| U-1603d | a missing subject under a symlinked project root reports "missing subject file" — `zfa tdd compose` | AC3 | unit | DONE | test/plugins/tdd/commands/compose_command_test.dart |
| U-1603e | a missing subject under a symlinked project root reports "missing subject file" — `zfa tdd wire` | AC4 | unit | DONE | test/plugins/tdd/wire_command_test.dart |

## Notes

- The macOS condition is reproduced deterministically on Linux: create the
  fixture root as a REAL directory, alias it with a symlink, and pass the
  SYMLINK path as `--project`. The raw (symlink) cwd then canonicalizes to a
  different prefix — the exact shape macOS gets for free from
  `/var/folders` → `/private/var/folders`.
- U-1603a is the direct regression for the issue's U-V3 signature.
- Guard semantics are frozen: no verify gate, closure scan, or
  already-implemented/already-wired path changes.
