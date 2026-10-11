# Plan: 1277-plan-traces-cell-contract-names

**Template Version**: `zuraffa-1.0`

## Summary

Make the declared-signature generation path (`DeclaredRouting.
declaredSignatureFor`, the #1259 remediation) reachable through the
standard plan→gen pipeline by having `zfa tdd plan` write the FULL trace
set — criterion id + the behavior's resolved contract-row names — into
the test-list and lane-plan `traces` cells, instead of the criterion id
alone.

## Technical Context

- **Primary site**: `lib/src/plugins/tdd/commands/plan_command.dart`
  - `_derivedLaneRows` (~line 1795): sets `traces: b.sourceCriterion`
    — the criterion id only — for every lane row it derives.
  - Legacy single-file writers in `_render` (~lines 978 / 1009 / 1022):
    the acceptance / widget / unit tables each print
    `${b.sourceCriterion}` as the traces cell.
  - The contract names already parsed at plan time:
    `frTraces = SpecParser.parseFrContractTraces(specMd)` (~line 550),
    keyed by the parser's document-wide unit id (`currentId`), consumed
    today only by `_provenanceLines` (~line 1428) for routing
    provenance — never written into cells.
- **Downstream consumers that already accept the shape**:
  - `TestListReader` (`lib/src/plugins/tdd/services/
    test_list_reader.dart`): reads the traces cell positionally from
    the pipe-split row cells — any cell text round-trips.
  - `RoutingResolver` (`lib/src/plugins/tdd/services/
    routing_resolver.dart`): `_resolveToken` accepts exact row names
    (`TodoRepository`) and method-qualified references
    (`TodoRepository.create`); `_criterionToken` skips `FR-001`-shaped
    tokens.
  - `DeclaredRouting.declaredSignatureFor`: tokenizes the cell with
    `SpecParser.traceTokens` and resolves against the spec's contract
    rows — the cell is documented as "a raw string
    (`FR-001, Formatter.format`)".
  - `make` (`_rowTraces`): tokenizes the same cell the same way.
- **Coupled site that must move with the writers**:
  - The re-plan reconciliation read (`run()`, ~lines 439–457) parses
    the PRIOR test list's rows with
    `RegExp(r'^\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|')` and
    keys id reconciliation by the cell text. That character class
    cannot span `.` or survive a comma-greedy space, so once cells
    carry `FR-001, TodoRepository.create` the match degrades to the
    state cell (`PENDING`) and id stability breaks. The read must
    resolve the cell positionally and key by the cell's leading
    criterion token.

## Design

1. Build a `contractTraces` map in `run()` where `expressibleEntries`
   (behavior ↔ `currentId` pairing) and `frTraces` are both in scope:
   `behavior.id → frTraces[currentId]` (non-empty only).
2. Render the traces cell through one helper:
   `criterion` when the behavior has no resolved contract names
   (backward-compatible fallback), otherwise
   `criterion, name1, name2…`. Tokens equal to the criterion are
   dropped (no self-duplicates).
3. Wire the helper into the three legacy writers (acceptance / widget /
   unit; contract rows already carry method-qualified criterion cells
   and stay verbatim) and into `_derivedLaneRows`.
4. Replace the reconciliation regex read with a positional parse:
   match the leading id cell, split the remaining cells on `|`, take
   the second-to-last cell as the traces cell (state is last), key the
   reconciliation map by the cell's first comma-separated token (the
   criterion id).

## Out of scope (hard constraints)

- No changes to `RoutingResolver`, `DeclaredRouting`, `gen`, `make`,
  the contract scanner, or the verify gate semantics.
- Preserved ffi rows (`_ffiLaneRows`, the `## Native loop` writer) keep
  their hand-authored verbatim cells.
- Contract-lane rows keep their `Interface.method` criterion cells.

## Risk & compatibility

- Old committed lists (criterion-only cells) reconcile identically:
  the first comma-token of `FR-001` is `FR-001`.
- `dart format` + `dart analyze` on changed files; targeted tests only
  (plan command suites + the new #1310 suite) per the cloud-agent test
  scope.
