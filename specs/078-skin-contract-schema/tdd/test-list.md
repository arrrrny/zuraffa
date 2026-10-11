# Test List: 078-skin-contract-schema

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | a typed model is returned with every field populated and the schema version reported. | AC-1 | PENDING |
| A2 | it fails with an error naming the offending section/key — never a silent default. | AC-2 | PENDING |
| A3 | `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1). | AC-3 | PENDING |
| A4 | every model field has a schema property and every schema property traces to a model field (no drift, no orphans). | AC-4 | PENDING |
| A5 | no schema file is written and nothing else about the plan changes. | AC-5 | PENDING |
| A6 | every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass. | AC-6 | PENDING |
| A7 | it fails naming the spec file and the violating key. | AC-7 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows. | FR-001 | PENDING |
| U2 | The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields. | FR-002 | PENDING |
| U3 | The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee). | FR-003 | PENDING |
| U4 | `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section. | FR-004 | PENDING |
| U5 | The emitted schema MUST be generated from the typed model's fields so the two cannot drift. | FR-005 | PENDING |
| U6 | A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named. | FR-006 | PENDING |
| U7 | The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators). | FR-007 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A7 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

