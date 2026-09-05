# Traceability: 079-skin-contract-binding

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:0c7503722480a6709104104ffdc155f810d5504384ff1fa13361e57d775ca30d
statements: 13
automated: 13
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** a contract declaring routes `/login` and `/register`, **When** the binding derives the route table, **Then** both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction. | A1 | automated |
| AC-2 | 26 | 2. **Given** a contract with no routes, **When** the binding derives the table, **Then** no route except the root is allowed. | A2 | automated |
| AC-3 | 40 | 1. **Given** a contract whose `states` declare `error: toaster` for LoginPage and `error: inline` for RegisterPage, **When** the binding derives state bindings, **Then** LoginPage maps to the toaster binding and RegisterPage to inline. | A3 | automated |
| AC-4 | 41 | 2. **Given** a contract whose `stateRows` declare two audit rows, **When** the binding derives the row descriptors, **Then** both descriptors carry their declared ids and kinds. | A4 | automated |
| AC-5 | 55 | 1. **Given** a parsed contract, **When** the binding is built, **Then** it exposes the route table, the state bindings, and the contract name it was built from. | A5 | automated |
| AC-6 | 56 | 2. **Given** two different contracts, **When** bindings are built, **Then** each keeps its own identity and route set (no cross-contamination). | A6 | automated |
| FR-001 | 68 | - **FR-001**: The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call. | U1 | automated |
| FR-002 | 69 | - **FR-002**: The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule. | U2 | automated |
| FR-003 | 70 | - **FR-003**: The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations. | U3 | automated |
| FR-004 | 71 | - **FR-004**: The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind. | U4 | automated |
| FR-005 | 72 | - **FR-005**: The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source. | U5 | automated |
| FR-006 | 73 | - **FR-006**: The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart). | U6 | automated |
| FR-007 | 74 | - **FR-007**: The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary. | U7 | automated |

