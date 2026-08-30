# Data Model: `zfa tdd run`

## Entities

### RunOutcome (enum — new)

| Value | Meaning | Exit |
|-------|---------|------|
| `complete` | every behavior DONE with complete evidence | 0 |
| `stopped` | a step failed; behavior + step named | ≠0 |
| `corrupt-state` | run-state.json unreadable/invalid | ≠0 |
| `concurrent-run` | in-flight marker held by another run | ≠0 |
| `runner-error` | step spawn/profile/tooling failure | ≠0 |

### RunState (existing — extended)

Current: `feature`, `behaviorStates` (id → pending|red|green|done),
`inFlightBehaviorId`, `inFlightStep`; `advance`, `markInFlight`,
`toJson`/`fromJson`.

Added (file persistence, 041 T074):

- `RunStateStore.load(featureDir)` → `RunState` or corruption error
- `RunStateStore.save(featureDir, state)` — atomic (temp file + rename)
- Behaviors whose rows disappeared from `test-list.md` are retained with a
  `dropped` marker field (never deleted — audit trail)

### StepResult (value object — new)

- `step` (gen | verify-red | make | refactor)
- `behaviorId`, `exitCode`, `outcome` (parsed from the step's summary line),
- `success` (exit 0 AND contract-consistent summary), `output`

### EvidenceSets (value object — new)

- `red` (Set<String> behavior ids), `green` (Set<String>) — from
  `cycle-log.md` section parsing (`^- behavior:` / `^- kind: red|green$`).

### BehaviorRow (value object — new)

Parsed `test-list.md` row: `id`, `description`, `traces`, `state`,
`kind` (from section header).

## State Transitions

Per behavior (spec FR-001):

```text
PENDING --gen ok + verify-red certified--> RED
RED     --make green-->                    GREEN
GREEN   --refactor clean|refactored-->     DONE
any     --step failure-->                  unchanged (run stops)
done-claim without red+green evidence -->  demoted to evidence-backed state
```

Run-level:

```text
start → load state → reconcile with evidence → drive →
  all DONE → complete (0)
  step failure → stopped (≠0, behavior+step named)
```

## File Contracts

- `specs/<feature>/tdd/test-list.md` — read-only (4-column plan format).
- `specs/<feature>/tdd/run-state.json` — read/write, atomic saves.
- `specs/<feature>/tdd/cycle-log.md` — read-only here (steps write it).
- Target project `test/`, `lib/` — never touched by the driver itself.
