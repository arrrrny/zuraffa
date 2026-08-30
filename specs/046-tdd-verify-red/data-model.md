# Data Model: `zfa tdd verify-red`

## Entities

### RedClassification (enum — new)

Six-way outcome of a verification run (spec FR-004):

| Value | Meaning | Exit | Log entry |
|-------|---------|------|-----------|
| `assertion` | honest red — assertion failure in the target test | 0 | appended |
| `compile-error` | subject/test does not compile | ≠0 | none |
| `load-error` | test file cannot load (missing file/import) | ≠0 | none |
| `skipped` | test skipped/pending | ≠0 | none |
| `unexpected-green` | test passed | ≠0 | none |
| `runner-error` | infrastructure failure, timeout, blended or unexplained run | ≠0 | none |

Validation rule: exactly one class per run; `assertion` is the only class
that certifies red.

### RunRecord (value object — new, classifier input)

- `command` (String) — the resolved runner command, post `{file}`/`{name}`
  substitution
- `exitCode` (int)
- `output` (String) — combined stdout/stderr
- `startedProcess` (bool) — false when the executable failed to launch
- `testCount` (int?) — parsed count of executed tests; null when unparseable

Validation rule: `testCount != 1` forces `runner-error` (spec FR-005),
except when classification already landed on `load-error`/`compile-error`.

### CycleLogEntry (existing — extended)

Current fields: `behaviorId`, `kind` (red|green), `runnerCommand`,
`exitCode`, `capturedOutput`, `classification` (`FailureClass?`).

Added fields (spec FR-006):

- `sourceCriterion` (String) — e.g. `FR-007`, from the artifact record
- `testPath` (String) — registry-recorded test path
- `timestamp` (String, ISO-8601 UTC)

`FailureClass` widened with `skipped` and `runnerError` so the log can
faithfully record the six-way classification if future commands log
rejections; `verify-red` itself only ever logs `assertionFailure`.

### ArtifactRecord (existing — read-only consumer)

Fields consumed: `behaviorId`, `feature`, `sourceCriterion`, `testPath`,
`runnableTestName`. Never written by this command.

## State Transitions

Per-behavior loop state (owned by the future `zfa tdd run`; this command only
produces the evidence that justifies the `RED` transition):

```text
PENDING --gen--> GENERATED --verify-red: assertion--> RED
GENERATED --verify-red: any other class--> GENERATED (unchanged; non-zero exit)
```

## File Contracts

- `specs/<feature>/tdd/artifacts.json` — read-only here.
- `specs/<feature>/tdd/cycle-log.md` — append-only; new entry shape in
  [contracts/verify-red.md](contracts/verify-red.md).
