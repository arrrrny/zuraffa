# Test List: 1313-parse-fr-block-contract-traces

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the trace binds (`U1 -> [RouteContentType]`) and `zfa tdd plan` routes the behavior to the declared contract lane (`route: U1 -> unit lane [declared: contract row: RouteContentType...`) with no `[fallback:` line. | AC-1 | PENDING |
| A2 | plan prints the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` instead of silently falling back to the legacy classifier with zero author-facing hint. | AC-2 | PENDING |
| A3 | every contract-row provenance line names the declared row (e.g. `route: contract:A1 -> contract lane [declared: RouteContentType]`) instead of the anonymous `[declared: layer contracts section]` label whose synthesized `contract:A1` ids match neither the declared row names nor the AC ids. | AC-3 | PENDING |
| A4 | single-line `traces:` bindings are unchanged and FRs without `traces:` keep the labeled legacy fallback routing. | AC-4 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `parseFrContractTraces` MUST consume the entire FR block — every continuation line after the FR header until the next FR/requirement header (bullet or FR-table row), a markdown heading, or an acceptance scenario header — and bind a `traces:` line found anywhere in that block, not just on the single line immediately after the header; the U-id numbering stays aligned with `_extractUnit` (one U per FR header in document order). | FR-001 | PENDING |
| U2 | When an FR block contains a `traces:` line but the FR produced no contract-row binding (the binding map has no non-empty token list for the FR's unit id), `zfa tdd plan` MUST emit the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` naming the offending FR id, on stdout and in the routing-provenance artifact, so the gap is author-visible instead of a silent fallback. | FR-002 | PENDING |
| U3 | The routing provenance for derived contract behaviors MUST name the declared contract row the behavior was derived from (the Layer Contracts interface name, e.g. `RouteContentType`), replacing the anonymous `[declared: layer contracts section]` provenance detail. | FR-003 | PENDING |
| U4 | Backward compatibility: an FR with `traces:` on the line immediately after the header binds exactly the same tokens as before (including the backticked-signature drop rule); an FR block whose first `traces:` line binds wins over later `traces:` lines in the same block; FRs with no `traces:` line in their block produce no binding and keep the labeled fallback routing. | FR-004 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 8]
route: A2 -> acceptance lane [declared: type marker, spec line 10]
route: A3 -> acceptance lane [declared: type marker, spec line 12]
route: A4 -> acceptance lane [declared: type marker, spec line 14]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

