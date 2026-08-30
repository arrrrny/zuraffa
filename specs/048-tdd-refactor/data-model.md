# Data Model: `zfa tdd refactor`

## Entities

### RefactorOutcome (enum — new)

| Value | Meaning | Exit | Evidence |
|-------|---------|------|----------|
| `clean` | suite green before/after; zero actions needed | 0 | optional no-op entry |
| `refactored` | suite green before/after; ≥1 action applied | 0 | appended |
| `not-green` | preflight failed (failing tests named) | ≠0 | none |
| `regression` | post-refactor suite red (regressed tests named) | ≠0 | none |
| `runner-error` | profile/tooling/parse failure | ≠0 | none |

### RefactorAction (value object — new)

- `name` (String) — pass name, e.g. `build`, `format`, `fix`
- `command` (String) — the exact invoked command line
- `exitCode` (int)
- `filesChanged` (List<String>) — project-relative paths the pass changed
  (from the before/after snapshot diff scoped to the pass)
- `output` (String) — captured tool output (trimmed)

Validation rule: a pass that changed no files records `filesChanged: []`;
passes are executed in registry order and a failing pass stops the rest.

### CycleLogEntry (existing — extended)

- `CycleEntryKind` gains `refactor`.
- Assert relaxed to `kind != red || classification != null` (red entries keep
  the classification requirement; refactor entries never carry one).
- `toMarkdown()` renders the correct `red|green|refactor` label and, for
  refactor entries, an `actions:` block listing each RefactorAction's
  command, exit code, and changed files.

### TreeSnapshot (value object — new, shared service)

- `entries` (Map<String,String>) — path → `file:<sha256>` / `directory` /
  `link:<target>`
- `changedPaths(other)` — symmetric diff of paths and hashes

### TddProfile / CycleLog (existing — read/append consumers)

- `suite` key drives preflight and re-proof runs.

## State Transitions

This command does not advance per-behavior loop state; it is the
green-keeping step the loop driver invokes between `make` and `DONE`:

```text
GREEN --refactor: clean|refactored--> GREEN (suite re-proven)
GREEN --refactor: regression|runner-error--> unsafe; named in report
* --refactor: not-green--> refused (suite was red at preflight)
```

## File Contracts

- `specs/<feature>/tdd/cycle-log.md` — append-only; refactor entries only on
  `refactored` (or explicit no-op `clean`).
- `.specify/memory/tdd-profile.md` — read-only (`suite`).
- Target project `test/` — byte-identical before/after, always.
- Target project `lib/` — may change only via recorded RefactorActions.
