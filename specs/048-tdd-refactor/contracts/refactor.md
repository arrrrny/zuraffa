# Contract: `zfa tdd refactor`

## CLI

```text
zfa tdd refactor [--feature <feature-dir-name>] [--project <path>]
```

- `--project` — target project root (absolute or relative); defaults to the
  current directory. Same convention as the other tdd commands.
- `--feature` — feature whose `tdd/` directory receives the evidence entry.
- **No flag may weaken the preflight** — a skip option does not exist (spec
  FR-002).

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | suite green before and after; zero or more recorded actions applied (`clean` or `refactored`) |
| ≠0 | `not-green` / `regression` / `runner-error` — refactor state unsafe |

## Summary line (machine-readable)

Final stdout line, stable key=value format:

```text
refactor: feature=<feature> outcome=<clean|refactored|not-green|regression|runner-error> applied=<n>
```

Examples:

```text
refactor: feature=048-tdd-refactor outcome=refactored applied=2
refactor: feature=048-tdd-refactor outcome=not-green applied=0
```

## Refactor-evidence cycle-log entry (append-only)

Written on `refactored` (and optionally for `clean`, explicitly marked no-op):

```markdown
## Cycle: refactor (refactor)

- behavior: -
- kind: refactor
- command: `dart test`
- exit: 0
- at: 2026-08-30T12:00:00.000Z
- preflight: 128 passed, 0 failed
- actions:
  - build: `zfa build` (exit 0) — lib/src/domain/entities/product/product.g.dart
  - format: `dart format lib/` (exit 0) — (no files)
- after: 128 passed, 0 failed
```

Field order fixed; a no-op entry carries `actions: (none — clean)`.

## Errors

All rejections print `zfa tdd refactor: <outcome> — <detail>` to stderr
before the summary line: `not-green` names every failing test and points to
`zfa tdd make`; `regression` names the regressed tests; `runner-error` names
the failing tool/profile.

## Integrity guarantees

- `test/` is byte-identical before/after every run (verified by tree
  snapshot; a violation is itself a hard failure).
- Every `lib/` change appears in at least one recorded action's
  `filesChanged`; unattributed edits are a hard failure.
- Writes to `cycle-log.md` only on `refactored`/`clean`, append-only.
