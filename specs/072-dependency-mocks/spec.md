# Feature Specification: Dependency-Table Mocks (contract-conforming mocks from declared dependency rows)

**Feature Branch**: `072-dependency-mocks`

**Created**: 2026-09-03

**Status**: Draft

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/960 — [ZIKZAK-REBUILD] dependency-table mocks: FirebaseAuth/Hive-class touchpoints get certified mocks from the declared contract (the unconsumed half of mock-first)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A declared dependency row yields a contract-conforming mock (Priority: P1)

A spec author declares an external dependency in the zuraffa-1.0 template's **External Dependencies & Contracts** table — name, kind, contract signatures, mock priority — e.g. `FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1`. A new generation surface, `zfa mock dependency <Name>`, reads that declared row and generates a mock package for the dependency: the declared interface (method names, parameter lists, return types exactly as the row's contract declares), a certified fake implementation with scriptable per-method responses, and a fixture lane so tests can stage scenarios against it. The generated surface is derived from the declaration alone — never from an entity, and never from guesswork about what the dependency "probably" exposes. Regenerating from an unchanged row is byte-for-byte deterministic.

**Why this priority**: This is the unconsumed half of mock-first. Entity datasources already get certified mocks; an app's real external touchpoints (auth, storage, HTTP) never do, so every feature built on them falls back to hand-written stubs the machine cannot certify. Without this, mock-first stops exactly where ZikZak's hardest wiring begins.

**Independent Test**: Can be fully tested by declaring a dependency row with a two-method contract, running `zfa mock dependency <Name>`, and confirming the generated interface exposes exactly those methods with exactly those signatures, that a scripted-response fake is present for each method, that re-running produces identical bytes, and that a row for an undeclared name refuses with the row to add. Delivers: machine-certified mocks for the dependencies an app actually has.

**Acceptance Scenarios**:

1. **Given** a spec declaring `FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1`, **When** `zfa mock dependency FirebaseAuth` runs, **Then** the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members.
2. **Given** the generated mock, **When** a test scripts a response for a declared method and invokes it, **Then** the fake returns exactly the scripted value and records the call (arguments and order) for later assertion.
3. **Given** the same dependency row, **When** `zfa mock dependency FirebaseAuth` runs twice, **Then** the generated artifacts are byte-for-byte identical.
4. **Given** `zfa mock dependency Vendure` with no declared row for `Vendure`, **When** the command runs, **Then** it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.
5. **Given** the `Hive` storage row declared in the same spec, **When** the same rail runs for it, **Then** the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds).

---

### User Story 2 - Behaviors tracing to a dependency row test against its mock (Priority: P2)

When the loop plans a behavior whose trace names a declared dependency row, the behavior tests against that dependency's generated mock — the declared-routing seam (071) routes the behavior to the dependency-mock surface, the generated mock is wired into the behavior's harness, and the routing provenance names the dependency row consulted. Prose wording never decides this: a requirement saying "authenticates the user" with no trace to a declared row is NOT routed to a dependency mock, and one tracing to `FirebaseAuth` is routed there even if its wording never mentions authentication.

**Why this priority**: A generated mock nobody consumes is shelf-ware. The routing seam is what turns dependency mocks into the loop's default test double for the touchpoints a feature declares — and it reuses the declaration ladder 071 built, keeping "route on declarations, not prose" true one level deeper.

**Independent Test**: Can be fully tested by writing a spec whose unit behaviors trace to declared dependency rows (mixed with behaviors that do not), then confirming each traced behavior's harness wires the row's generated mock, its provenance names the row, and untraced behaviors remain on their own surfaces. Delivers: features declare their touchpoints once and every traced test automatically tests against the certified mock.

**Acceptance Scenarios**:

1. **Given** a unit behavior tracing to the declared `FirebaseAuth` row, **When** the behavior's test harness is generated, **Then** the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.
2. **Given** the same behavior, **When** the routing provenance is read, **Then** it names the dependency row (dependency name + contract) as the consulted declaration.
3. **Given** a requirement "authenticates the user" with no trace to any declared dependency, **When** generation is planned, **Then** the behavior is NOT routed to a dependency mock (no prose sniffing).
4. **Given** a behavior tracing to a dependency row whose mock was never generated, **When** the loop reaches it, **Then** the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.

---

### User Story 3 - Mock priority orders generation in the loop (Priority: P3)

Each declared row's mock priority (P1/P2/P3) orders dependency-mock generation in the loop: P1 rows are materialized before P2, P2 before P3, and rows with no declared priority after all prioritized ones (stably ordered by declaration order within a tier). An author reading the plan sees the order the mocks will be built and why.

**Why this priority**: The loop materializes what the plan needs first; without declared priority the ordering is arbitrary and the highest-risk touchpoints (the ones features block on) are as likely to come last. Priority makes mock-first's build order a declaration too.

**Independent Test**: Can be fully tested by declaring rows with priorities P2, P1, (none), P3 and confirming the loop's generation order is exactly P1, P2, P3, none — stable across runs and visible in the plan artifact. Delivers: declared build order for the touchpoint mocks.

**Acceptance Scenarios**:

1. **Given** rows declared with priorities P2, P1, (none), P3, **When** the loop generates dependency mocks, **Then** the materialization order is exactly P1, P2, P3, none.
2. **Given** two rows sharing a priority tier, **When** generation is ordered, **Then** their relative order equals their declaration order in the spec, stably across runs.
3. **Given** a produced plan, **When** the dependency-mock section is read, **Then** each row's priority and resulting order position are visible.

---

### User Story 4 - `realize` swaps the dependency mock behind the same interface (Priority: P4)

`zfa tdd realize --adapter <Name>` treats a generated dependency mock exactly like an entity datasource mock: the real adapter implements the declared interface, the differential gates (mock vs real parity, #913) run, and the suite stays green through the swap. The declared contract row is the arbitration source for parity — a real adapter whose surface drifts from the row refuses with the drift named.

**Why this priority**: Mock-first's promise is "swap later, nothing else changes"; dependency mocks must ride the same rail or they become a second-class mock flavor with its own swap ritual.

**Independent Test**: Can be fully tested by generating a dependency mock, implementing the declared interface, running `zfa tdd realize --adapter <Name>`, and confirming the parity gates run against the declared contract and the suite stays green (and that a drifting real adapter refuses naming the drifted method). Delivers: the same swap-later promise for dependencies that entity mocks already have.

**Acceptance Scenarios**:

1. **Given** a generated dependency mock and a real adapter implementing the declared interface, **When** `zfa tdd realize --adapter <Name>` runs, **Then** the differential gates compare against the declared contract and the suite stays green through the swap.
2. **Given** a real adapter whose surface omits a declared method, **When** realize runs, **Then** it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.
3. **Given** the swapped state, **When** the behaviors that trace to the row run, **Then** they run unchanged against the real adapter (same interface, same harness seam).

---

### Edge Cases

- What happens when the contract signatures are malformed (missing return type, unparseable parameter list)? The command refuses naming the row and the exact malformed segment — never generates a guessed mock.
- What happens when two rows declare the same dependency name? Refuse naming both spec lines (duplicates are ambiguous, mirroring the #846 duplicate-id rule).
- What happens when a declared kind is unknown (not service/storage/channel-class)? The row is accepted for declaration purposes, and the mock generator either supports the kind or refuses naming the unsupported kind — never a silently wrong-shaped mock.
- What happens when a generated mock already exists and the row changed? Regeneration overwrites deterministically and the change is surfaced in the command output (same-row → byte-identical is the no-change case).
- What happens when a behavior traces to a row whose kind the mock surface does not support? Refuse naming the row and the unsupported kind — never a silently wrong-shaped test double.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.
- **FR-002**: The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members.
- **FR-003**: The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.
- **FR-004**: Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.
- **FR-005**: A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.
- **FR-006**: A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.
- **FR-007**: Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact.
- **FR-008**: A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.
- **FR-009**: `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.
- **FR-010**: Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.

### Key Entities *(include if feature involves data)*

- **SpecDependency**: one declared row of the External Dependencies & Contracts table — `dependency` (name), `type` (kind), `contract` (declared signatures), `mockPriority` (P1/P2/P3/unprioritized). The single source of truth the mock surface is generated from.
- **DependencyMock**: the generated artifact package for one declared row — declared interface, certified fake with scriptable responses and call recording, fixture lane; recorded in the artifact registry, traceable to the row.
- **DependencyMockBinding**: the harness seam by which a behavior tracing to a row tests against that row's generated mock.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A login-feature spec declaring `FirebaseAuth` (service) and `Hive` (storage) with their contracts produces both dependency mocks in one loop run, in priority order, with zero hand-written test doubles for either touchpoint.
- **SC-002**: 100% of behaviors tracing to a declared dependency row test against that row's generated mock, with provenance naming the row; 0 behaviors route to a dependency mock from prose alone.
- **SC-003**: Regenerating an unchanged row produces byte-identical artifacts (determinism check passes on repeat).
- **SC-004**: A real `FirebaseAuth`-class adapter implementing the declared interface passes `zfa tdd realize --adapter FirebaseAuth` with the suite green; a drifting adapter refuses naming the drift.
- **SC-005**: Every malformed-row case in Edge Cases refuses with the row and defect named; 0 malformed rows produce a generated artifact.

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| Hive | storage | openBox(name) -> Box, put(key, value) -> void | P2 |

## Assumptions

- The declared-row grammar is the zuraffa-1.0 template's existing External Dependencies & Contracts table (already parsed into the plan artifact and readable via the existing dependency reader); this feature consumes it, it does not redefine it.
- "Certified mock" follows the existing mock-first machinery's meaning (declared surface, scriptable responses, call recording, registered artifacts), extended from entity datasources to declared dependency rows.
- The declared-routing seam (071) provides the trace→declaration lookup this feature consumes; no new routing mechanism is introduced here.
- Target surface is the ZikZak touchpoint list named in the issue (service/storage classes such as FirebaseAuth, Hive, Vendure; platform channels already have their own certified-fake rail) — not an open-ended taxonomy of dependency kinds.
- Realize's differential gates (#913) are reused as-is, pointed at the declared contract as the parity source.
