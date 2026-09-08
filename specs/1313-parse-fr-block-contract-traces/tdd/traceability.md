# Traceability: 1313-parse-fr-block-contract-traces

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:80c467f6cb60bd7aa769f333095d35602458db62c60a0b33b2fc6ee86bfb10cd
statements: 8
automated: 8
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 7 | 1. **Given** a spec whose FR bullet wraps onto continuation lines with the `traces:` row-name line after the wrap (the issue #1319 repro: `- **FR-001**: System MUST expose POST /conversation/stream that returns\n  Content-Type: text/event-stream with structured JSON events.\n          traces: RouteContentType`) **When** `parseFrContractTraces` parses the spec **Then** the trace binds (`U1 -> [RouteContentType]`) and `zfa tdd plan` routes the behavior to the declared contract lane (`route: U1 -> unit lane [declared: contract row: RouteContentType...`) with no `[fallback:` line. | A1 | automated |
| AC-2 | 9 | 2. **Given** a spec where an FR block contains a `traces:` line that did not bind to a contract row **When** `zfa tdd plan` runs **Then** plan prints the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` instead of silently falling back to the legacy classifier with zero author-facing hint. | A2 | automated |
| AC-3 | 11 | 3. **Given** a spec declaring `## Layer Contracts` rows **When** `zfa tdd plan` renders the routing provenance **Then** every contract-row provenance line names the declared row (e.g. `route: contract:A1 -> contract lane [declared: RouteContentType]`) instead of the anonymous `[declared: layer contracts section]` label whose synthesized `contract:A1` ids match neither the declared row names nor the AC ids. | A3 | automated |
| AC-4 | 13 | 4. **Given** pre-existing single-line specs (an FR bullet with `traces:` on the immediately following line, and FRs without any `traces:` continuation) **When** the parser and plan run **Then** single-line `traces:` bindings are unchanged and FRs without `traces:` keep the labeled legacy fallback routing. | A4 | automated |
| FR-001 | 18 | - **FR-001**: `parseFrContractTraces` MUST consume the entire FR block — every continuation line after the FR header until the next FR/requirement header (bullet or FR-table row), a markdown heading, or an acceptance scenario header — and bind a `traces:` line found anywhere in that block, not just on the single line immediately after the header; the U-id numbering stays aligned with `_extractUnit` (one U per FR header in document order). | U1 | automated |
| FR-002 | 19 | - **FR-002**: When an FR block contains a `traces:` line but the FR produced no contract-row binding (the binding map has no non-empty token list for the FR's unit id), `zfa tdd plan` MUST emit the loud warning `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` naming the offending FR id, on stdout and in the routing-provenance artifact, so the gap is author-visible instead of a silent fallback. | U2 | automated |
| FR-003 | 20 | - **FR-003**: The routing provenance for derived contract behaviors MUST name the declared contract row the behavior was derived from (the Layer Contracts interface name, e.g. `RouteContentType`), replacing the anonymous `[declared: layer contracts section]` provenance detail. | U3 | automated |
| FR-004 | 21 | - **FR-004**: Backward compatibility: an FR with `traces:` on the line immediately after the header binds exactly the same tokens as before (including the backticked-signature drop rule); an FR block whose first `traces:` line binds wins over later `traces:` lines in the same block; FRs with no `traces:` line in their block produce no binding and keep the labeled fallback routing. | U4 | automated |

