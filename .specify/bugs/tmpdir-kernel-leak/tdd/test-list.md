# Test List: tmpdir-kernel-leak

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | only the stale dir is selected and the | AC-1 | PENDING |
| A2 | the two created dirs are deleted and the | AC-2 | PENDING |
| A3 | the loop fails fast with | AC-3 | PENDING |
| A4 | the startup sweep ran once before the first spawn | AC-4 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the TDD loop startup MUST sweep stale package:test kernel temp | FR-001, TempKernelSweep.planStartupSweep | PENDING |
| U2 | the loop MUST snapshot the temp-kernel dir set before running | FR-002, TempKernelSweep.deltaCreated | PENDING |
| U3 | before a FULL-suite invocation (the unscoped baseline | FR-003, DiskPreflight.check | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in `spec.md` Layer Contracts (issue #1007). A contract test proves the implementation satisfies the DECLARED contract — a failing contract test is BLOCKED (never RED) and blocks the cycle from proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | TempKernelSweep.planStartupSweep(String tmpDir, DateTime now, Duration maxAge) -> List<String> (interface method contract) | TempKernelSweep.planStartupSweep | PENDING |
| contract:A2 | TempKernelSweep.deltaCreated(Set<String> before, Set<String> after) -> List<String> (interface method contract) | TempKernelSweep.deltaCreated | PENDING |
| contract:A3 | DiskPreflight.check(int freeBytes, int suiteCount, int perSuiteBytes, int marginBytes) -> String? (interface method contract) | DiskPreflight.check | PENDING |

## Layer contracts

### Function

- `TempKernelSweep`: `planStartupSweep(String tmpDir, DateTime now, Duration maxAge) -> List<String>`, `deltaCreated(Set<String> before, Set<String> after) -> List<String>`
- `DiskPreflight`: `check(int freeBytes, int suiteCount, int perSuiteBytes, int marginBytes) -> String?`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 48]
route: A2 -> acceptance lane [declared: type marker, spec line 53]
route: A3 -> acceptance lane [declared: type marker, spec line 58]
route: A4 -> acceptance lane [declared: type marker, spec line 62]
route: U1 -> unit lane (func surface) [declared: contract row: TempKernelSweep, spec line 39]
route: U2 -> unit lane (func surface) [declared: contract row: TempKernelSweep, spec line 39]
route: U3 -> unit lane (func surface) [declared: contract row: DiskPreflight, spec line 40]
route: contract:A1 -> contract lane [declared: TempKernelSweep]
route: contract:A2 -> contract lane [declared: TempKernelSweep]
route: contract:A3 -> contract lane [declared: DiskPreflight]

