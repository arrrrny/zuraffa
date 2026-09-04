# Test List: 072-dependency-mocks

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members. | AC-1 | PENDING |
| A2 | the fake returns exactly the scripted value and records the call (arguments and order) for later assertion. | AC-2 | PENDING |
| A3 | the generated artifacts are byte-for-byte identical. | AC-3 | PENDING |
| A4 | it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add. | AC-4 | PENDING |
| A5 | the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds). | AC-5 | PENDING |
| A6 | the harness wires the generated `FirebaseAuth` mock and the behavior tests through it. | AC-6 | PENDING |
| A7 | it names the dependency row (dependency name + contract) as the consulted declaration. | AC-7 | PENDING |
| A8 | the behavior is NOT routed to a dependency mock (no prose sniffing). | AC-8 | PENDING |
| A9 | the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double. | AC-9 | PENDING |
| A10 | the materialization order is exactly P1, P2, P3, none. | AC-10 | PENDING |
| A11 | their relative order equals their declaration order in the spec, stably across runs. | AC-11 | PENDING |
| A12 | each row's priority and resulting order position are visible. | AC-12 | PENDING |
| A13 | the differential gates compare against the declared contract and the suite stays green through the swap. | AC-13 | PENDING |
| A14 | it refuses naming the missing method and the contract row — never silently swapping a drifting adapter. | AC-14 | PENDING |
| A15 | they run unchanged against the real adapter (same interface, same harness seam). | AC-15 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared. | FR-001 | PENDING |
| U2 | The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members. | FR-002 | PENDING |
| U3 | The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions. | FR-003 | PENDING |
| U4 | Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output. | FR-004 | PENDING |
| U5 | A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock. | FR-005 | PENDING |
| U6 | A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double. | FR-006 | PENDING |
| U7 | Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact. | FR-007 | PENDING |
| U8 | A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock. | FR-008 | PENDING |
| U9 | `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row. | FR-009 | PENDING |
| U10 | Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature. | FR-010 | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| Hive | storage | openBox(name) -> Box, put(key, value) -> void | P2 |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A7 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A8 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A9 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A10 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A11 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A12 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A13 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A14 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A15 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U9 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U10 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

