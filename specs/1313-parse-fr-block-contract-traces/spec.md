**Template Version**: `zuraffa-1.0`

# Spec: 1313-parse-fr-block-contract-traces

## Acceptance Scenarios

1. **Given** a spec whose FR bullet wraps onto continuation lines with the `traces:` row-name line after the wrap (the issue #1319 repro: `- **FR-001**: System MUST expose POST /conversation/stream that returns\n  Content-Type: text/event-stream with structured JSON events.\n          traces: RouteContentType`) **When** `parseFrContractTraces` parses the spec **Then** the trace binds (`U1 -> [RouteContentType]`) and `zfa tdd plan` routes the behavior to the declared contract lane (`route: U1 -> unit lane [declared: contract row: RouteContentType...`) with no `[fallback:` line.
   **Type**: acceptance
2. **Given** a spec where an FR block contains a `traces:` line that did not bind to a contract row **When** `zfa tdd plan` runs **Then** plan prints the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` instead of silently falling back to the legacy classifier with zero author-facing hint.
   **Type**: acceptance
3. **Given** a spec declaring `## Layer Contracts` rows **When** `zfa tdd plan` renders the routing provenance **Then** every contract-row provenance line names the declared row (e.g. `route: contract:A1 -> contract lane [declared: RouteContentType]`) instead of the anonymous `[declared: layer contracts section]` label whose synthesized `contract:A1` ids match neither the declared row names nor the AC ids.
   **Type**: acceptance
4. **Given** pre-existing single-line specs (an FR bullet with `traces:` on the immediately following line, and FRs without any `traces:` continuation) **When** the parser and plan run **Then** single-line `traces:` bindings are unchanged and FRs without `traces:` keep the labeled legacy fallback routing.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: `parseFrContractTraces` MUST consume the entire FR block — every continuation line after the FR header until the next FR/requirement header (bullet or FR-table row), a markdown heading, or an acceptance scenario header — and bind a `traces:` line found anywhere in that block, not just on the single line immediately after the header; the U-id numbering stays aligned with `_extractUnit` (one U per FR header in document order).
- **FR-002**: When an FR block contains a `traces:` line but the FR produced no contract-row binding (the binding map has no non-empty token list for the FR's unit id), `zfa tdd plan` MUST emit the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` naming the offending FR id, on stdout and in the routing-provenance artifact, so the gap is author-visible instead of a silent fallback.
- **FR-003**: The routing provenance for derived contract behaviors MUST name the declared contract row the behavior was derived from (the Layer Contracts interface name, e.g. `RouteContentType`), replacing the anonymous `[declared: layer contracts section]` provenance detail.
- **FR-004**: Backward compatibility: an FR with `traces:` on the line immediately after the header binds exactly the same tokens as before (including the backticked-signature drop rule); an FR block whose first `traces:` line binds wins over later `traces:` lines in the same block; FRs with no `traces:` line in their block produce no binding and keep the labeled fallback routing.
