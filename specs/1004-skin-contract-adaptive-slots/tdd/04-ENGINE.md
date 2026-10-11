# Engine Plan: 1004-skin-contract-adaptive-slots (CORE + BOTH)

The engine lane (issue #1000): pure Dart — behaviors whose lane is CORE or BOTH. The noFlutter guard rejects any behavior that references Flutter at plan time, so this file stays engine-only.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `tdd/04-SKIN.md` carries the platform-contract rows, the state-machine rows, and the route-contract rows. | AC-1 | PENDING |
| A2 | the contract is JSON-parseable and validates against the generated JSON Schema. | AC-2 | PENDING |
| A3 | the plan refuses with exit 2 naming the drift and writes no artifacts. | AC-3 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system shall parse the spec's `## Skin Contract` yaml section into the typed adaptive contract (adaptive_slots, platform_overrides, states, routes), refusing unknown, duplicate, or missing keys by name. | FR-001 | PENDING |
| U2 | The system shall render the platform matrix rows, the state-machine rows, and the route rows into `tdd/04-SKIN.md`, tied to the skin-lane behaviors. | FR-002 | PENDING |
| U3 | The system shall emit the machine JSON contract block generated from the typed model and validate it against the model-generated JSON Schema in tests. | FR-003 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]


