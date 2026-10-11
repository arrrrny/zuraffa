# Test List: 1653-mutation-test-opt-in-pre-resolve

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | dev_dependencies gain the testing baseline | AC-1 | PENDING |
| A2 | `mutation_test: ^1.8.0` is present. | AC-2 | PENDING |
| A3 | the resolver ran at init time and its duration | AC-3 | PENDING |
| A4 | the entry carries preflight/registry/re-proof | AC-4 | PENDING |
| A5 | init misfires naming the resolver output. | AC-5 | PENDING |
| A6 | the entry still parses and the chain | AC-6 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `PubspecDevDependenciesPatcher` gains `includeMutationTest` | FR-001, PubspecDevDependenciesPatcher.ensure | PENDING |
| U2 | `TddBaselineInit.ensure` gains `mutation` (default false) and | FR-002, TddBaselineInit.ensure | PENDING |
| U3 | `zfa tdd init` exposes `--mutation` (negatable: false) whose | FR-003, InitCommand.run | PENDING |
| U4 | when the dependency writers newly added entries, init runs the | FR-004, TddBaselineInit.ensure | PENDING |
| U5 | a resolver run that exits non-zero fails the init sequence | FR-005, TddBaselineInit.ensure | PENDING |
| U6 | `RefactorCommand` measures the three phases and prints | FR-006, RefactorCommand | PENDING |
| U7 | the refactor cycle-log entry renders | FR-007, CycleLogEntry | PENDING |
| U8 | `RefactorPasses` records each pass's wall duration into its | FR-008, RefactorAction | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in `spec.md` Layer Contracts (issue #1007). A contract test proves the implementation satisfies the DECLARED contract — a failing contract test is BLOCKED (never RED) and blocks the cycle from proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | PubspecDevDependenciesPatcher.ensure(String, {bool, bool, bool}) -> Future<List<String>> (interface method contract) | PubspecDevDependenciesPatcher.ensure | PENDING |
| contract:A2 | TddBaselineInit.ensure({String, bool, bool, bool, Function, Function, Function}) -> Future<BaselineInitReport> (interface method contract) | TddBaselineInit.ensure | PENDING |
| contract:A3 | InitCommand.run() -> Future<void> (interface method contract) | InitCommand.run | PENDING |

## Layer contracts

### Function

- `PubspecDevDependenciesPatcher`: `ensure(String, {bool, bool, bool}) -> Future<List<String>>`
- `TddBaselineInit`: `ensure({String, bool, bool, bool, Function, Function, Function}) -> Future<BaselineInitReport>`
- `InitCommand`: `run() -> Future<void>`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 132]
route: A2 -> acceptance lane [declared: type marker, spec line 135]
route: A3 -> acceptance lane [declared: type marker, spec line 140]
route: A4 -> acceptance lane [declared: type marker, spec line 144]
route: A5 -> acceptance lane [declared: type marker, spec line 147]
route: A6 -> acceptance lane [declared: type marker, spec line 151]
route: U1 -> unit lane (func surface) [declared: contract row: PubspecDevDependenciesPatcher, spec line 174]
route: U2 -> unit lane (func surface) [declared: contract row: TddBaselineInit, spec line 175]
route: U3 -> unit lane (func surface) [declared: contract row: InitCommand, spec line 176]
route: U4 -> unit lane (func surface) [declared: contract row: TddBaselineInit, spec line 175]
route: U5 -> unit lane (func surface) [declared: contract row: TddBaselineInit, spec line 175]
route: U6 -> refused [danglingReference: behavior "U6" traces to "RefactorCommand", which names no declared contract row (Key Entities, Layer Contracts, or External Dependencies).]
route: U7 -> refused [danglingReference: behavior "U7" traces to "CycleLogEntry", which names no declared contract row (Key Entities, Layer Contracts, or External Dependencies).]
route: U8 -> refused [danglingReference: behavior "U8" traces to "RefactorAction", which names no declared contract row (Key Entities, Layer Contracts, or External Dependencies).]
route: contract:A1 -> contract lane [declared: PubspecDevDependenciesPatcher]
route: contract:A2 -> contract lane [declared: TddBaselineInit]
route: contract:A3 -> contract lane [declared: InitCommand]

