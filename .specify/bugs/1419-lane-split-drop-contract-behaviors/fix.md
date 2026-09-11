# Fix: lane-split plan includes derived Layer Contract behaviors with BLOCKED semantics (#1419)

- **Slug**: 1419-lane-split-drop-contract-behaviors
- **Fixed in**: `lib/src/plugins/tdd/commands/plan_command.dart`,
  `lib/src/plugins/tdd/services/lane_split.dart`
  (branch `fix/1419-lane-split-drop-contract-behaviors`)
- **Strategy**: count the derived contract behaviors into the lane
  contract and render their rows into the engine plan — the same
  section shape the legacy single-file path writes — instead of
  repairing the artifact after the fact or teaching the SKIN lane to
  render contract rows it can never run.

## 1. Split path: contract rows join the ENGINE row list, rendered by the shared renderer

New `_contractLaneRows(contractBehaviors, laneResult)` mirrors
`_ffiLaneRows`: one `LaneRow` per derived contract behavior with the
derived description (`Interface.method(...) -> Type (entity method
contract)`), the `Interface.method` trace (`b.sourceCriterion`), the
contract kind, the reconciled state (`b.state.name.toUpperCase()` —
PENDING on first plan, a recorded BLOCKED survives re-plans), and the
resolver's lane (CORE by default). The rows join the `engineRows` list,
so the summary/verdict counts, the meta-index, the BOTH seam table, and
the UI ledger see them exactly the way the legacy path counts
`contractBehaviors`. They do NOT join `skinRows`: `_resolveLanes`
refuses every non-CORE declaration of a derived contract id, so a
contract row can never be `destinedForSkin` and the spread would be
filtered out on every run.

The contract-loop section itself is written by the SHARED engine
renderer: `renderContractLoopSection(buf, rows)` in `lane_split.dart`
(the same title `## Contract loop: contract behaviors`, the same intro,
the same 4-column rows, description `_escapeCell`-ed) is called from
`renderEnginePlan` over the `BehaviorKind.contract` rows the renderer
already receives, and from the legacy `_render` path over its
`contractBehaviors`. One writer, so `zfa tdd plan` and `zfa tdd split` —
which both call `renderEnginePlan` — cannot diverge on the same shared
renderer. `TestListReader` resolves the section with
`kind = BehaviorKind.contract` unchanged, so gen/make/run/verify keep
their spec-1007 semantics (a failing contract test is BLOCKED, never
RED) on the split path for the first time.

## 2. Lane-coverage counting: `_resolveLanes` sees `contractBehaviors`

New optional parameter `contractBehaviors` (default `const []`). After
the ffi rows' CORE default, the derived contract behaviors count into
the classification:

- **CORE by default** — `classification.putIfAbsent(b.id, () =>
  Lane.core)`: an undeclared contract behavior lands engine-side (the
  issue's expected outcome), and the meta-index's CORE row now RESOLVES
  the `contract:A<n>` ids (the lane-coverage accounting sees them —
  pre-fix nothing counted them, which is why the drop had no witness).
- **A non-engine declaration refuses** — a `contract:A<n>` id declared
  into a SKIN/BOTH lane adds a refusal naming id/criterion with the
  CORE-move remedy: the SKIN plan renders no contract section, so
  honoring the declaration would drop the row from the split artifacts
  again (the same silent-drop class), and a skin-side contract test
  contradicts spec 1007 (a contract test is pure Dart). Refusal exits 2
  writing no lane artifacts — errors-are-an-API.
- **The engine purity guard applies** — a contract row whose
  description/criterion references `package:flutter` refuses (the
  engine lane is pure Dart by construction; the remedy names the
  signature fix).

`_heuristicLaneResolution` (the issue #1309 stale-split regeneration
path) takes `contractBehaviors` too and classifies them CORE, so a
regenerated split carries the same contract rows as a Lanes-declared
plan (pinned by A-1419-8).

## 3. Hand-rows branch: consult derived contract behaviors first

The hand-rows `derivedIds` set gains the contract behavior ids, so a
`contract:A<n>` declaration in `## Lanes` never falls through to the
anonymous `core behavior declared in ## Lanes` hand row (which
pre-fix clobbered the derived description, the `Interface.method`
trace, and the contract kind with `LANE:CORE` + unit kind). The
declared CORE id joins the derived behavior; the row the plan emits is
the contract-loop row.

## Not changed (hard constraints)

- the lane-split renderers' other sections, `split_command.dart`'s
  classification/refusal logic, the core engine cycle, gen pipeline,
  verify gate, spec-parser — untouched;
- the reader (`test_list_reader.dart`) — untouched; it already spoke
  the contract-loop shape the legacy path writes and the split path now
  writes too.

The `zfa tdd split` legacy-list migration gap the review flagged is
CLOSED by §1: the section moved into the renderer both commands call, so
the migrated `04-ENGINE.md` now carries the contract rows its own
meta-index and receipt already classified (pinned by A-1419-9, which is
red against the previous commit that wrote the section at the `plan`
call site).
