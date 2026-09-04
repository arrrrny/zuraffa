# Test List: 074-plugin-merge-contract

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the host's route barrel is regenerated to include the feature's routes. | AC-1 | PENDING |
| A2 | it resolves to the feature's page. | AC-2 | PENDING |
| A3 | the only changes outside the feature's own artifacts are regenerated barrels (no manual wiring). | AC-3 | PENDING |
| A4 | the feature's binding module registers through the host's locator in both mock and real flavors. | AC-4 | PENDING |
| A5 | every token the feature declares resolves (the graph constructs fully). | AC-5 | PENDING |
| A6 | every dependency touchpoint serves the certified mock. | AC-6 | PENDING |
| A7 | each page composes behind the host's adaptive shell convention. | AC-7 | PENDING |
| A8 | it refuses naming the off-convention artifact. | AC-8 | PENDING |
| A9 | a machine-readable verdict reports routes/DI/feature-suite each passing and the host lands committed. | AC-9 | PENDING |
| A10 | the routes check fails, the host is rolled back byte-identical to pre-merge, and the exit is non-zero naming the failed check. | AC-10 | PENDING |
| A11 | the feature-suite check fails, the host rolls back, and the failure names the red behavior. | AC-11 | PENDING |
| A12 | they are byte-identical. | AC-12 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | Merge MUST regenerate the host's route barrel to include the merged feature's routes; hand-edited host routing is never required and never performed. | FR-001 | PENDING |
| U2 | Every declared route path MUST resolve to the feature's page in the merged host (route-resolution check). | FR-002 | PENDING |
| U3 | Merge MUST register the feature's bindings through the host's service locator in mock and real flavors; the DI-graph construction check MUST construct the full graph in the merged host. | FR-003 | PENDING |
| U4 | Merged views MUST compose behind the host's adaptive shell convention; off-convention view artifacts MUST be refused naming the artifact. | FR-004 | PENDING |
| U5 | Merge MUST run the conformance suite (routes resolve, DI graph constructs, feature suite green in-host) after landing, producing a machine-readable verdict with one line per check. | FR-005 | PENDING |
| U6 | Any conformance failure MUST roll the host back byte-identical to its pre-merge state, exit non-zero, and name the failed checks. | FR-006 | PENDING |
| U7 | The feature-suite gate MUST compare against a pre-merge baseline: pre-existing reds never fail a merge; new reds always do. | FR-007 | PENDING |
| U8 | Merge MUST be idempotent — re-merging a merged feature changes nothing and re-runs the gates. | FR-008 | PENDING |
| U9 | Every refusal and every failed gate MUST name the offending artifact, token, or behavior with a `--> fix:` hint. | FR-009 | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| HostRouter | service | routes() -> List, register(route) -> void | P1 |
| HostDI | service | bind(token, factory) -> void, resolve(token) -> Object | P1 |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 33]
route: A2 -> acceptance lane [declared: type marker, spec line 35]
route: A3 -> acceptance lane [declared: type marker, spec line 37]
route: A4 -> acceptance lane [declared: type marker, spec line 52]
route: A5 -> acceptance lane [declared: type marker, spec line 54]
route: A6 -> acceptance lane [declared: type marker, spec line 56]
route: A7 -> acceptance lane [declared: type marker, spec line 71]
route: A8 -> acceptance lane [declared: type marker, spec line 73]
route: A9 -> acceptance lane [declared: type marker, spec line 88]
route: A10 -> acceptance lane [declared: type marker, spec line 90]
route: A11 -> acceptance lane [declared: type marker, spec line 92]
route: A12 -> acceptance lane [declared: type marker, spec line 94]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U9 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

