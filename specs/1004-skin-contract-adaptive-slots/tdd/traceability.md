# Traceability: 1004-skin-contract-adaptive-slots

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:cf75762cf4fecfe6db30e9facecb139aebbdf30b3610d4f59ea5c774a3bfb0c8
statements: 6
automated: 6
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 51 | 1. **Given** a spec declaring `## Skin Contract` with `adaptive_slots`, `platform_overrides`, `states`, and `routes`, **When** `zfa tdd plan <feature>` runs, **Then** `tdd/04-SKIN.md` carries the platform-contract rows, the state-machine rows, and the route-contract rows. | A1 | automated |
| AC-2 | 52 | 2. **Given** the emitted `04-SKIN.md`, **When** the fenced JSON block is extracted and parsed, **Then** the contract is JSON-parseable and validates against the generated JSON Schema. | A2 | automated |
| AC-3 | 53 | 3. **Given** a spec whose Skin Contract drifts (an unknown key, no `## Lanes`, or adaptive_slots disagreeing with the SKIN lane), **When** `zfa tdd plan <feature>` runs, **Then** the plan refuses with exit 2 naming the drift and writes no artifacts. | A3 | automated |
| FR-001 | 57 | - **FR-001**: The system shall parse the spec's `## Skin Contract` yaml section into the typed adaptive contract (adaptive_slots, platform_overrides, states, routes), refusing unknown, duplicate, or missing keys by name. | U1 | automated |
| FR-002 | 58 | - **FR-002**: The system shall render the platform matrix rows, the state-machine rows, and the route rows into `tdd/04-SKIN.md`, tied to the skin-lane behaviors. | U2 | automated |
| FR-003 | 59 | - **FR-003**: The system shall emit the machine JSON contract block generated from the typed model and validate it against the model-generated JSON Schema in tests. | U3 | automated |

