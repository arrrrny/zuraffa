# Test List: missing-subject-symlink-root (#1603)

**Feature**: `.specify/bugs/missing-subject-symlink-root` (bug TDD mode)
**Source**: `spec.md` — derived via the LLM-guided fallback path
(speckit.tdd.plan; engine detection: ZFA_MISSING — no `.zfa.json` in this repo)
**Suite**: `test/plugins/tdd/commands/view_command_test.dart`

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1603-1 | a missing subject under an explicit symlinked project root is the missing-file refusal, never "outside the project root" | FR-001 | unit | DONE | test/plugins/tdd/commands/view_command_test.dart |
| U1603-2 | a recorded subject that genuinely resolves outside the root is still refused as outside-root | FR-002 | unit | DONE | test/plugins/tdd/commands/view_command_test.dart |
| U-V3 | the pre-existing missing-subject pin (red on macOS pre-fix: the fixture root itself traverses `/var` → `/private/var`) must stay green | FR-001 | unit | DONE | test/plugins/tdd/commands/view_command_test.dart |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1603-1 | the symlinked-root subject refusal exits non-zero naming the missing subject file | AC-1 | DONE |
| A1603-2 | the genuine-outside refusal is unchanged by the fix | AC-2 | DONE |

## Coverage

- U1603-1 + U-V3 trace to FR-001 (AC-1).
- U1603-2 traces to FR-002 (AC-2).
- Out of scope: sibling commands — `wire_command.dart` already carries the fix
  (`c1e287da`, PR #1516 review); `compose_command.dart` checks the missing file
  BEFORE the outside-root comparison; `func_command.dart` compares the raw forms
  of the same normalized base (relative recorded paths never trip it).
