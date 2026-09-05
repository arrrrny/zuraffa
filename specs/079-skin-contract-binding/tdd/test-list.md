# Test List: 079-skin-contract-binding

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction. | AC-1 | PENDING |
| A2 | no route except the root is allowed. | AC-2 | PENDING |
| A3 | LoginPage maps to the toaster binding and RegisterPage to inline. | AC-3 | PENDING |
| A4 | both descriptors carry their declared ids and kinds. | AC-4 | PENDING |
| A5 | it exposes the route table, the state bindings, and the contract name it was built from. | AC-5 | PENDING |
| A6 | each keeps its own identity and route set (no cross-contamination). | AC-6 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call. | FR-001 | PENDING |
| U2 | The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule. | FR-002 | PENDING |
| U3 | The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations. | FR-003 | PENDING |
| U4 | The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind. | FR-004 | PENDING |
| U5 | The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source. | FR-005 | PENDING |
| U6 | The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart). | FR-006 | PENDING |
| U7 | The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary. | FR-007 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

