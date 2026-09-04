# Traceability: 072-dependency-mocks

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:4195cae934b2c2d87c140bf6905aac6e6e26a143862ba95c7a214a6ba76e5435
statements: 25
automated: 25
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** a spec declaring `FirebaseAuth \| service \| signIn(email, password) -> User, signOut() -> void \| P1`, **When** `zfa mock dependency FirebaseAuth` runs, **Then** the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members. | A1 | automated |
| AC-2 | 26 | 2. **Given** the generated mock, **When** a test scripts a response for a declared method and invokes it, **Then** the fake returns exactly the scripted value and records the call (arguments and order) for later assertion. | A2 | automated |
| AC-3 | 27 | 3. **Given** the same dependency row, **When** `zfa mock dependency FirebaseAuth` runs twice, **Then** the generated artifacts are byte-for-byte identical. | A3 | automated |
| AC-4 | 28 | 4. **Given** `zfa mock dependency Vendure` with no declared row for `Vendure`, **When** the command runs, **Then** it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add. | A4 | automated |
| AC-5 | 29 | 5. **Given** the `Hive` storage row declared in the same spec, **When** the same rail runs for it, **Then** the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds). | A5 | automated |
| AC-6 | 43 | 1. **Given** a unit behavior tracing to the declared `FirebaseAuth` row, **When** the behavior's test harness is generated, **Then** the harness wires the generated `FirebaseAuth` mock and the behavior tests through it. | A6 | automated |
| AC-7 | 44 | 2. **Given** the same behavior, **When** the routing provenance is read, **Then** it names the dependency row (dependency name + contract) as the consulted declaration. | A7 | automated |
| AC-8 | 45 | 3. **Given** a requirement "authenticates the user" with no trace to any declared dependency, **When** generation is planned, **Then** the behavior is NOT routed to a dependency mock (no prose sniffing). | A8 | automated |
| AC-9 | 46 | 4. **Given** a behavior tracing to a dependency row whose mock was never generated, **When** the loop reaches it, **Then** the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double. | A9 | automated |
| AC-10 | 60 | 1. **Given** rows declared with priorities P2, P1, (none), P3, **When** the loop generates dependency mocks, **Then** the materialization order is exactly P1, P2, P3, none. | A10 | automated |
| AC-11 | 61 | 2. **Given** two rows sharing a priority tier, **When** generation is ordered, **Then** their relative order equals their declaration order in the spec, stably across runs. | A11 | automated |
| AC-12 | 62 | 3. **Given** a produced plan, **When** the dependency-mock section is read, **Then** each row's priority and resulting order position are visible. | A12 | automated |
| AC-13 | 76 | 1. **Given** a generated dependency mock and a real adapter implementing the declared interface, **When** `zfa tdd realize --adapter <Name>` runs, **Then** the differential gates compare against the declared contract and the suite stays green through the swap. | A13 | automated |
| AC-14 | 77 | 2. **Given** a real adapter whose surface omits a declared method, **When** realize runs, **Then** it refuses naming the missing method and the contract row — never silently swapping a drifting adapter. | A14 | automated |
| AC-15 | 78 | 3. **Given** the swapped state, **When** the behaviors that trace to the row run, **Then** they run unchanged against the real adapter (same interface, same harness seam). | A15 | automated |
| FR-001 | 94 | - **FR-001**: The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared. | U1 | automated |
| FR-002 | 95 | - **FR-002**: The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members. | U2 | automated |
| FR-003 | 96 | - **FR-003**: The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions. | U3 | automated |
| FR-004 | 97 | - **FR-004**: Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output. | U4 | automated |
| FR-005 | 98 | - **FR-005**: A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock. | U5 | automated |
| FR-006 | 99 | - **FR-006**: A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double. | U6 | automated |
| FR-007 | 100 | - **FR-007**: Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact. | U7 | automated |
| FR-008 | 101 | - **FR-008**: A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock. | U8 | automated |
| FR-009 | 102 | - **FR-009**: `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row. | U9 | automated |
| FR-010 | 103 | - **FR-010**: Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature. | U10 | automated |

