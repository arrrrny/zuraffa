# Test List: 073-slice-isolation

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A2 | it is green — no test references the host. | AC-2 | PENDING |
| A4 | the certified channel fake from the tdd plugin is installed in the sandbox's DI. | AC-4 | PENDING |
| A5 | the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding). | AC-5 | PENDING |
| A6 | the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host. | AC-6 | PENDING |
| A7 | they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host. | AC-7 | PENDING |
| A8 | every step succeeds without host knowledge. | AC-8 | PENDING |
| A9 | it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing. | AC-9 | PENDING |
| A10 | it exits non-zero, its verdict marks self-containment failed, and the offending reference is named. | AC-10 | PENDING |
| A11 | mock certification fails naming the unbound dependency. | AC-11 | PENDING |
| A12 | the feature's artifacts, journal, and registry land in the host. | AC-12 | PENDING |
| A13 | it is green. | AC-13 | PENDING |
| A14 | it refuses naming the failed check (merge requires a verified slice). | AC-14 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the sandbox contains the feature's spec, tdd artifacts, an app shell, a router harness exposing exactly the feature's routes, and DI wiring binding certified mocks for every declared dependency. | AC-1 | PENDING |
| A3 | the route resolves and renders through the mock DI bindings. | AC-3 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `zfa slice cut --feature <f> --from <host>` MUST produce a sandbox project carrying the feature's spec, tdd artifacts, a runnable app shell, a router harness exposing exactly the feature's declared routes, and DI wiring binding certified mocks for every declared dependency touchpoint. | FR-001 | PENDING |
| U2 | The sandbox MUST be self-contained: its suite runs green with the host unavailable, and no generated file references the host. | FR-002 | PENDING |
| U3 | The tdd loop MUST run with the sandbox as project root, and its journal/registry evidence MUST live inside the sandbox. | FR-003 | PENDING |
| U4 | `zfa slice verify` MUST emit a machine-readable JSON verdict covering self-containment, mock certification, and suite state, exiting non-zero and naming the failing check and offending references on failure. | FR-004 | PENDING |
| U5 | `zfa slice merge --into <host>` MUST land the feature's artifacts, journal, and registry into the host and MUST refuse when verify's verdict is failing or absent. | FR-005 | PENDING |
| U6 | After merge, the HOST suite MUST run green; merge reports the host-suite outcome. | FR-006 | PENDING |
| U7 | Cut scaffolding MUST be deterministic: unchanged inputs produce byte-identical wiring. | FR-007 | PENDING |
| U8 | Every refusal across cut/verify/merge MUST name the offending path, reference, or check with a `--> fix:` hint. | FR-008 | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1 |
| GoRouterHost | service | routeFor(path) -> PageRoute | P1 |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> widget lane [fallback: legacy description classifier matched — add `**Type**: widget` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> widget lane [fallback: legacy description classifier matched — add `**Type**: widget` to the scenario]
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
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

