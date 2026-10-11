# Tasks 1313 — scan the full FR block for `traces:`; warn on unbound traces
      (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are implemented after the
green loop (speckit.implement).

## Phase 0 — parser: block-continuation scan (RED)

- [x] T0.1 Write `test/plugins/tdd/services/spec_parser_traces_1319_test.dart`:
      the #1319 repro spec (wrapped FR bullet + `traces:` after the wrap)
      binds `U1 -> [RouteContentType]` via `parseFrContractTraces`.
      [FR-001, AC-1]
- [x] T0.2 Same file: block boundaries — a `traces:` line after the next
      FR header binds to the SECOND FR only (U2), never U1; a `traces:`
      line after a markdown heading binds to nothing; a `traces:` line
      after an acceptance scenario header binds to nothing.
      [FR-001, FR-004]
- [x] T0.3 Same file: the FR-table form — `traces:` after a variant
      continuation row (empty id cell) binds; a single-line FR with
      `traces:` on the immediately following line binds the same tokens
      as before (backticked-signature drop included). [FR-001, FR-004]

## Phase 1 — unbound detection + plan provenance (RED)

- [x] T1.1 Same file: `findUnboundFrTraces` — an FR whose block has a
      `traces:` line with no binding (empty tokens / missing key) is
      reported by FR id; a bound FR is not; an ownerless `traces:` line
      (after a heading) is not. [FR-002]
- [x] T1.2 Write `test/plugins/tdd/commands/plan_unbound_traces_1319_test.dart`:
      `zfa tdd plan` prints the exact line `WARNING: traces: line found
      in FR-001 but was not bound to a contract row — check indentation`
      for a spec whose FR block carries an unbindable `traces:` line.
      [FR-002, AC-2]
- [x] T1.3 Same file: plan provenance names the declared row for derived
      contract behaviors (`route: contract:A1 -> contract lane
      [declared: RouteContentType]`, `route: contract:A2 -> contract
      lane [declared: User]`). [FR-003, AC-3]
- [x] T1.4 Same file: the full #1319 repro end-to-end — plan routes the
      multi-line FR to the declared lane (`route: U1 -> unit lane`,
      `[declared: contract row: RouteContentType`, no `[fallback:`).
      [FR-001, AC-1]
- [x] T1.5 Update the pre-existing assertion in
      `contract_kind_1007_test.dart` from
      `[declared: layer contracts section]` to
      `[declared: User]` (the declared row the test's contract:A1 was
      derived from). [FR-003]
- [x] T1.6 Record RED evidence: the new suites fail against the
      unmodified tree; capture into tdd/verification.md.

## Phase 2 — GREEN implementation

- [x] T2.1 `spec_parser.dart` `parseFrContractTraces`: block-continuation
      scan (forward walk until the next FR header / heading / scenario
      header; first `traces:` line in the block wins); U-id numbering
      unchanged. [FR-001, FR-004]
- [x] T2.2 `spec_parser.dart`: add `findUnboundFrTraces(specMd, bound)`
      (owner attribution by nearest preceding FR header, headings and
      scenario headers end ownership; empty binding counts as unbound).
      [FR-002]
- [x] T2.3 `plan_command.dart`: compute the unbound set after the
      declarations parse, print the loud warning per offending FR id,
      record the warning line on the fallback-routed behavior's
      provenance entry; contract-behavior provenance names the declared
      row (`[declared: <Interface>]`). [FR-002, FR-003]
- [x] T2.4 Run the 1313 suites GREEN; re-run the guarded neighbors
      (`spec_parser_declarations_test.dart`,
      `spec_parser_hardening_1196_test.dart`,
      `routing_resolver_test.dart`, `plan_routing_provenance_test.dart`,
      `contract_kind_1007_test.dart`) to prove the backward-compat
      contract. [FR-004]

## Phase 3 — non-behavioral (speckit.implement)

- [x] T3.1 Commit the spec-kit artifacts (spec.md, plan.md, tasks.md,
      tdd/test-list.md, tdd/traceability.md, tdd/verification.md).
- [x] T3.2 `dart analyze` the touched files; `dart format .`; confirm
      zero formatting diffs.
- [x] T3.3 Conventional Commit `fix(1319): ...` per the commit convention +
      push + PR closing #1319 with the multi-line FR trace bind demo.
