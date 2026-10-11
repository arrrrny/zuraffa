# Traceability: 078-skin-contract-schema

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:1d2c23241ed3e27f57fac272298e4440dfede89b5551b76d3cd413800b3062d3
statements: 14
automated: 14
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** contract JSON containing routes, states, platform rows, state rows, and a schema version, **When** the parser runs, **Then** a typed model is returned with every field populated and the schema version reported. | A1 | automated |
| AC-2 | 26 | 2. **Given** contract JSON missing a required section or carrying an unknown structure, **When** the parser runs, **Then** it fails with an error naming the offending section/key — never a silent default. | A2 | automated |
| AC-3 | 40 | 1. **Given** a spec with `## Skin Contract:`, **When** `zfa tdd plan` runs, **Then** `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1). | A3 | automated |
| AC-4 | 41 | 2. **Given** the emitted schema, **When** it is compared against the typed model's fields, **Then** every model field has a schema property and every schema property traces to a model field (no drift, no orphans). | A4 | automated |
| AC-5 | 42 | 3. **Given** a spec without a Skin Contract section, **When** `zfa tdd plan` runs, **Then** no schema file is written and nothing else about the plan changes. | A5 | automated |
| AC-6 | 56 | 1. **Given** the repo's specs tree, **When** the schema test suite runs, **Then** every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass. | A6 | automated |
| AC-7 | 57 | 2. **Given** a spec whose contract JSON violates the schema, **When** the suite runs, **Then** it fails naming the spec file and the violating key. | A7 | automated |
| FR-001 | 72 | - **FR-001**: The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows. | U1 | automated |
| FR-002 | 73 | - **FR-002**: The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields. | U2 | automated |
| FR-003 | 74 | - **FR-003**: The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee). | U3 | automated |
| FR-004 | 75 | - **FR-004**: `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section. | U4 | automated |
| FR-005 | 76 | - **FR-005**: The emitted schema MUST be generated from the typed model's fields so the two cannot drift. | U5 | automated |
| FR-006 | 77 | - **FR-006**: A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named. | U6 | automated |
| FR-007 | 78 | - **FR-007**: The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators). | U7 | automated |

