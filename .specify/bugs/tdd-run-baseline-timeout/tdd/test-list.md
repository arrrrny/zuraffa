# Test List: bug-tdd-run-baseline-timeout

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record). | AC-1 | PENDING |
| A2 | the default 10-minute deadline still applies (no behavior change for small repos). | AC-2 | PENDING |
| A3 | it is allowed up to N and produces a usable snapshot. | AC-1 | PENDING |
| A4 | the baseline is cached ("baseline cached for this run") and A1's make step executes. | AC-1 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process. | FR-001 | PENDING |
| U2 | `zfa tdd make` MUST apply its `--timeout` override to its fallback live suite baseline. | FR-002 | PENDING |
| U3 | When `zfa tdd run` spawns `zfa tdd make`, the spawn MUST carry the run-level `--timeout` override so every spawned process shares one deadline (bug #742 contract). | FR-003 | PENDING |
| U4 | Absent an override, the 10-minute `defaultSuite` deadline MUST remain unchanged. | FR-004 | PENDING |
| U5 | A baseline that completes under the effective deadline MUST produce a parseable snapshot and a cached `run-baseline.json` exactly as the small-repo path does today. | FR-005 | PENDING |

