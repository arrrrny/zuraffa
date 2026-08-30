# Data Model: `zfa tdd make`

## Entities

### MakeOutcome (enum — new)

Outcome of a `make` run (drives summary line + exit code):

| Value | Meaning | Exit | Green entry |
|-------|---------|------|-------------|
| `green` | generated implementation, target test passes, suite guard clean | 0 | appended |
| `not-certified-red` | no red evidence in cycle log for the behavior | ≠0 | none |
| `drift` | target test already green before generation | ≠0 | none |
| `unexpressible` | planner cannot map behavior to pipeline steps | ≠0 | none |
| `generation-error` | a pipeline step failed or produced non-compiling output | ≠0 | none |
| `regression` | suite guard found NEW failures | ≠0 | none |
| `runner-error` | runner/profile/tooling failure | ≠0 | none |

### GenerationPlan (value object — new)

- `behaviorId`, `feature`, `sourceCriterion`
- `steps` (ordered list of `GenerationStepSpec`)
- `unexpressibleReason` (String?, null when expressible)

### GenerationStepSpec / GenerationStep (value objects — new)

- Spec: `args` (List<String> after the zfa entrypoint), `purpose` (String)
- Step (executed): `command` (full resolved command line), `exitCode`,
  `output`, `purpose`

Validation rule: a plan is either fully expressible (steps non-empty, ending
in `build`) or carries an `unexpressibleReason`; never both.

### SuiteSnapshot (value object — new)

- `command`, `exitCode`, `failedTests` (Set<String> of failing test
  identifiers parsed from runner output), `capturedAt`

Regression rule: `guard.failedTests - baseline.failedTests` must be empty.

### CycleLogEntry (existing — extended)

Added field:

- `generationSteps` (List<GenerationStep>, default empty) — rendered inside
  green entries as a fixed `generation:` block listing each recorded command
  and exit code (spec FR-006/FR-008).

Unchanged invariants: append-only; `classification` required iff kind=red.

### ArtifactRecord / TddProfile / RunRecord (existing — read-only consumers)

Consumed: `behaviorId`, `feature`, `sourceCriterion`, `testPath`,
`runnableTestName`; profile keys `single` and `suite`.

## State Transitions

Per-behavior loop state (the `run` spec owns the machine; this command
produces the evidence for the `GREEN` transition):

```text
RED --make: green--> GREEN
RED --make: any failure--> RED (unchanged; non-zero exit)
GENERATED/PENDING --make--> refused (not-certified-red)
GREEN --make--> drift refusal: non-zero, no generation, no duplicate entry
```

## File Contracts

- `specs/<feature>/tdd/artifacts.json` — read-only.
- `specs/<feature>/tdd/cycle-log.md` — read red evidence; append green entry
  on certification only.
- `.specify/memory/tdd-profile.md` — read-only (`single`, `suite`).
- Target project `test/` + `lib/` — test files never modified; `lib/` changes
  only through pipeline sub-processes (recorded as generation steps).
