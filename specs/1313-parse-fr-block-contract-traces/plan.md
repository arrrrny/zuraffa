# Plan 1313 — scan the full FR block for `traces:`; warn on unbound traces

## Technical Context

- Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0` respected);
  pure-Dart package — no Flutter SDK in the loop.
- Issue: `parseFrContractTraces` (`lib/src/plugins/tdd/services/spec_parser.dart`)
  inspects only `lines[i + 1]` — the single line after the FR header:

  ```dart
  final t = i + 1 < lines.length
      ? tracesLine.firstMatch(lines[i + 1])
      : null;
  ```

  Multi-line FRs are the common case (the zuraffa-1.0 template wraps FR
  text at ~80 cols), so a `traces:` continuation that sits after a
  wrapped continuation line is never seen: the trace silently fails to
  bind, plan keeps the `[fallback: ... trace FR to a declared contract
  row]` routing, and `zfa tdd run` dead-ends at `U1:make` with
  `outcome=vacuous-green` — the #1308 dead-end with zero hint that the
  author's `traces:` line was never read.
- Secondary: after declaring `## Layer Contracts`, the routing
  provenance lists derived contract rows as
  `route: contract:A1 -> contract lane [declared: layer contracts
  section]` — synthesized ids that match neither the declared row names
  (`RouteContentType` etc.) nor the AC ids. The declared row name is
  already available from the derivation (`sourceCriterion =
  '<Interface>.<method>'`).

## Touched surfaces (hard constraint: these only)

| Surface | Change |
|---|---|
| `lib/src/plugins/tdd/services/spec_parser.dart` — `parseFrContractTraces` | Block-continuation scan: after an FR header, walk forward until the next FR header (`_frLine`), a markdown heading, or an acceptance scenario header, and bind the FIRST `traces:` line in that block. U-id numbering unchanged (one U per FR header in document order). Plus a new pure helper `findUnboundFrTraces(specMd, bound)` that reports the FR ids whose block contains a `traces:` line that did not yield a non-empty binding — the plan-side loud-warning input. |
| `lib/src/plugins/tdd/commands/plan_command.dart` — routing provenance output | (1) Emit the loud `WARNING: traces: line found in FR-XXX but was not bound to a contract row — check indentation` (stdout + the provenance record of the fallback-routed behavior) whenever an unbound traces line exists. (2) The derived contract behaviors' provenance names the declared row: `route: contract:A1 -> contract lane [declared: RouteContentType]` replaces `[declared: layer contracts section]`. |

Untouched by contract: the core engine cycle, the test-list generation
(`_render` row shapes), the gen/make pipeline, the verify gate, the FR
body-text scanner (`_extractUnit`), `parsePersistenceDeclarations` (same
lines[i+1] shape but a different feature — out of scope), the
`RoutingResolver` (already names the declared row once the trace binds).

## Routing decision table (issue #1319)

| FR block content | binding | plan behavior |
|---|---|---|
| `traces:` immediately after the header (single-line FR) | unchanged | declared route naming the row — byte-identical to pre-fix |
| `traces:` after a wrapped continuation line | NEW: binds | declared route naming the row (was: silent fallback) |
| `traces:` after the next FR header / a heading / a scenario header | no binding (not in the block) | labeled fallback as before |
| `traces:` line present, binding empty (all tokens dropped, e.g. a lone backticked signature) | empty | fallback PLUS the loud `WARNING: traces: line found in FR-XXX …` |
| no `traces:` in the block | no binding | labeled fallback as before (legacy classifier window) |

## Implementation strategy

MVP-first, dependency-ordered (T1 → T4):

1. **T1 — block-continuation scan (RED).** Parser tests pin the
   repro binding, the block boundaries (next FR header, heading,
   scenario header), the FR-table variant-row case, and single-line
   backward compat.
2. **T2 — unbound-traces detection + plan warning (RED).**
   `findUnboundFrTraces` unit tests + a plan harness test asserting the
   exact `WARNING: traces: line found in FR-001 but was not bound to a
   contract row — check indentation` line on stdout.
3. **T3 — provenance names the declared row (RED).** Plan harness
   test asserting `route: contract:A1 -> contract lane [declared: User]`;
   the pre-existing `[declared: layer contracts section]` assertion in
   `contract_kind_1007_test.dart` is updated to the new contract.
4. **T4 — docs/spec artifacts (non-behavioral).** This feature's
   committed artifacts + the verification record.

Backward-compat guardrails: `spec_parser_declarations_test.dart`,
`spec_parser_hardening_1196_test.dart` (table FR traces),
`routing_resolver_test.dart` (backticked-signature drop),
`plan_routing_provenance_test.dart` (`[declared: contract row: Formatter`)
must stay green — the block scan's first-match-wins reproduces the old
binding for every input where the old binding fired.
