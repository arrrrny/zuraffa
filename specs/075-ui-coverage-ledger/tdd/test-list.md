# Test List: 075-ui-coverage-ledger

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the ledger contains one row per surface with kind text/route/affordance. | AC-1 | PENDING |
| A2 | its state reads DONE with the proving behavior ids named. | AC-2 | PENDING |
| A3 | the row exists with an empty prover and a state marking it unproven — visible at plan time, not after merge. | AC-3 | PENDING |
| A4 | it is not forced into the ledger (the ledger's source is the declared Presentation/route contract plus scenario surface markers, not every quotation). | AC-4 | PENDING |
| A5 | it exits 0 with a JSON verdict listing each surface proven. | AC-5 | PENDING |
| A6 | it exits non-zero and the verdict names the surface and its missing prover. | AC-6 | PENDING |
| A7 | merge is blocked with the gap named. | AC-7 | PENDING |
| A8 | the surfaces it would prove read NOT-DONE (green is the only proof). | AC-8 | PENDING |
| A9 | the overlay highlights exactly the unproven affordance and paints proven surfaces clean. | AC-9 | PENDING |
| A10 | the overlay reflects the new state on the next paint. | AC-10 | PENDING |
| A11 | it lists the ledger rows with their states (the deck drives the ledger, not a separate inventory). | AC-11 | PENDING |
| A12 | the deck lists each touchpoint with drive-able scenario entries. | AC-12 | PENDING |
| A13 | the certified fake serves the scripted responses (the demo runs on the certification, not a parallel fake). | AC-13 | PENDING |
| A14 | it names `zfa mock dependency <Name>` as the fix — no hand-authored stand-ins. | AC-14 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The plan MUST produce a per-feature UI surface ledger enumerating declared surfaces — static texts (quoted-literal contract), declared routes (Presentation contract row), and named affordances — each with kind, proving behavior ids, and state. | FR-001 | PENDING |
| U2 | A surface with no tracing behavior MUST appear in the ledger as unproven at plan time (visible, never omitted). | FR-002 | PENDING |
| U3 | Ledger state MUST derive from current evidence: a surface is DONE only when at least one of its provers is green; planned-but-red provers never count. | FR-003 | PENDING |
| U4 | `zfa tdd coverage` (the coverage gate) MUST emit a machine-readable JSON verdict (one line per surface: kind, proven-by, state) and exit 0 only when every row is DONE; failures name each unproven surface and its missing prover. | FR-004 | PENDING |
| U5 | The coverage gate MUST be wireable as a merge/landing gate: an incomplete ledger blocks the landing naming the gaps (composing with the conformance verdict of 074). | FR-005 | PENDING |
| U6 | With xray enabled, the overlay MUST paint surfaces by ledger state (proven clean, unproven highlighted), reading the ledger as its source of truth; with no ledger present it MUST report absence, never paint proof. | FR-006 | PENDING |
| U7 | The control deck MUST list ledger rows with states, and the xray mock scaffolder MUST wire to 072's dependency mocks so deck entries exist without hand authoring; a missing mock names the generation fix. | FR-007 | PENDING |
| U8 | Every refusal and gate failure MUST name the surface, the ledger row, or the missing artifact with a `--> fix:` hint. | FR-008 | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| XRayOverlay | service | enable() -> void, paint(state) -> void | P2 |

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
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

