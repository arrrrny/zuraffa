# Implementation Plan: 1134-presentation-contracted-views

Epic #1134, four ordered lanes (one commit per lane, red → green each).
Baseline: #1142 (adaptive skeleton from Presentation `adaptive_layouts`),
#1004 (Skin Contract), #1102 (runtime auditor), #963/#1141 (surface
ledger), #966/#1143 (typed ledger library — zero production callers),
#1149 (CLI refusal of grid/table layouts).

## Lane 1 — Adaptive layout contract (extends #1004, #1102)

**Files**:
- `lib/src/plugins/tdd/services/platform_layout_contract.dart` — add
  `resolve({contracts, skinContract})`: Presentation declaration wins;
  Skin Contract `adaptive_slots` is the fallback when no Presentation
  bullet declares slots; null when neither (single-layout, zero drift).
- `lib/src/plugins/tdd/commands/view_command.dart` — `_platformLayoutContract`
  resolves via the new `resolve()` (reads `spec.md` for the Skin Contract
  through `parseAdaptiveSkinContract`; fail-open on unreadable spec —
  same discipline as `_presentationComponents`).
- `lib/src/plugins/tdd/commands/plan_command.dart` — the ledger's
  `layoutSlots` uses the SAME resolution (one declaration, one slot set).

**Tests** (`test/plugins/tdd/services/platform_layout_contract_1134_test.dart`,
`test/plugins/tdd/commands/view_command_skin_contract_slots_test.dart`):
contract-fallback resolution, Presentation-wins precedence, view emission
with contract-driven slots (mobile + macos + ios + android stubs),
zero-drift single layout, plan ledger slot set from the contract.

## Lane 2 — View pipeline cleanup (fence + deterministic contract port)

**Files**:
- NEW `lib/src/tdd/services/view_generation_contract.dart` — the shared
  seam (the first code the two generators share, deliberately):
  `ViewFileKind { notFound, generatorWritten, tddSubject, handWritten }`,
  `ViewGenerationContract.inspect(content)`, `machineSummary(entity,
  outcome, files)`, outcome labels `scaffolded|already-implemented|error`.
- `lib/src/plugins/view/view_plugin.dart` — the deterministic contract
  lands in the plugin's generation funnel (the single seam both CLI
  paths share), not in the command layer: `_viewGenerationContract`
  derives the primary view path inline (`_primaryViewPath(config)`) and,
  before generation, inspects it → `generatorWritten`/`handWritten` ⇒
  skip the primary (missing companions are still scaffolded) + the
  `already implemented — nothing to scaffold` note when nothing was
  written + machine line + exit 0; `tddSubject` ⇒ refuse exit 1 naming
  the tdd generator + `--force` escape. After generation the plugin
  prints the machine summary line; the plugin's GeneratedFile list
  drives the `files=<n>` count.

**Tests** (`test/tdd/services/view_generation_contract_test.dart`,
`test/plugins/view/view_deterministic_contract_test.dart`): marker
classification (mainline marker, tdd subject doc comment, hand-written,
absent), machine summary format, double-run already-implemented (exit 0,
nothing written on 2nd run), fence refusal on tdd subject, force escape.

## Lane 3 — Typed UI coverage ledger (#963 + #966 merged)

**Files**:
- NEW `lib/src/plugins/tdd/services/typed_ledger_projection.dart` —
  derives `DeclaredLedgerRow`s: per behavior description via
  `FinderTaxonomy` (presence literal → presence; route-outcome literal →
  navigation; enabled-state literal → state with attribute;
  `absent:`/`is not shown` → absence with `notRenderedIn` from the
  scenario's Given clause; `while…in flight` chains → sequence with
  steps); component tokens → presence rows; i18n keys → presence rows
  (`t.<key>` surfaces); per-slot layout-key surfaces → presence rows.
- NEW `lib/src/tdd/services/typed_platform_ledger.dart` —
  `TypedPlatformRow (slot, surface, kind, provers, status
  traced|untraced)`, `derive(typedRows, slots, behaviorSlots)`,
  `kindSlotHeatmap(rows, slots)` (kind × slot `traced/total` cells,
  HIGHLIGHT on zero-traced), `toMarkdown`, `toJson` (status vocabulary
  `traced|untraced` — the epic's row grammar).
- `lib/src/plugins/tdd/commands/plan_command.dart` — `_writeUiLedger`
  extended (or sibling `_writeTypedLedger`): derive + write
  `tdd/typed-ledger.md` + `tdd/typed-ledger.json`
  (`TypedLedgerBuilder.derive(greenBehaviors: {})` at plan time — every
  row untraced, visible, never omitted); when slots are declared append
  the per-layout heatmap + platform rows.
- `lib/src/tdd/services/xray_ledger_binding.dart` —
  `XrayLedgerOverlay.renderPlatformHeatmap(rows, slots)` (per-layout
  kind-coverage lines, HIGHLIGHT on zero-traced cells — kind coverage,
  not surface count) + `XrayLedgerDeck.platformEntries(rows, slots)`
  (one entry per (slot, kind) with traced/untraced badge).

**Tests** (`test/plugins/tdd/services/typed_ledger_projection_test.dart`,
`test/tdd/services/typed_platform_ledger_test.dart`,
`test/plugins/tdd/commands/plan_typed_ledger_1134_test.dart`,
`test/tdd/services/xray_platform_heatmap_1134_test.dart`): five-kind
derivation from verbs, plan writes the artifact pair, heatmap shape
(kind rows × slot cells), overlay rendering, deck entries, untraced
plan-time shape, 075 ledger byte-stability (no drift).

## Lane 4 — shadcn vocabulary as TDD gate

**Files**:
- NEW `lib/src/plugins/tdd/services/widget_vocabulary_gate.dart` —
  `isWidgetReferenceToken` (excludes `key:` tokens, slot-declaration
  bullets, method-signature tokens containing `(`),
  `normalizeWidgetName` (strip shad/zfa/zuraffa prefix, lowercase),
  `WidgetVocabularyGate.validate(tokens, {vocabulary})` → violations
  with `--> fix: declare a zfa ui schema vocabulary name (zfa ui
  schema); grid/table are NOT implemented` naming each offender. The
  `vocabulary` argument defaults to the built-ins; the call sites below
  pass `NodeRegistry.load(projectRoot: …).allNames` so the project's
  registered composites (`.zfa/ui/components/`) validate too.
- `lib/src/plugins/tdd/commands/plan_command.dart` — validate
  Presentation component tokens when the plan carries widget-behavior
  rows; refusal exit 2, no artifacts (errors-are-an-API). Composites
  resolved from `repoRoot`.
- `lib/src/plugins/tdd/commands/view_command.dart` — validate the
  resolved `_presentationComponents` before render; refusal exit 1
  before any write. Composites resolved from `normalizedCwd`; a
  malformed Skin Contract shape is translated to a
  `PlatformLayoutContractException` so the named refusal +
  machine-summary path fires.
- `lib/src/plugins/skin/builders/skin_builder.dart` — REMOVE the silent
  `default:` fall-through: `case 'list'`/`case 'form'` explicit; an
  unknown layout (grid/table/anything else) refuses BY NAME — the
  builder PRINTS the refusal (naming the layout, the implemented set
  list/form, and the `zfa ui schema` vocabulary) and returns `const []`,
  so `generate` writes NOTHING. The non-zero exit rides the invocation
  layer's zero-files guard (`zfa skin grid|table` is a hidden refuse
  subcommand exiting `usage`); no exception type was introduced.

**Tests** (`test/plugins/tdd/services/widget_vocabulary_gate_test.dart`,
`test/plugins/tdd/commands/plan_vocabulary_gate_1134_test.dart`,
`test/plugins/tdd/commands/view_vocabulary_gate_test.dart`,
`test/skin/builders/skin_builder_layout_refusal_test.dart`):
normalization matrix (ShadInput→input ✓, ZfaButton→button ✓,
ShadGrid→grid ✗, table ✗), method-signature/key/slot exclusions, plan
refusal (exit 2, no artifacts), view refusal (exit 1, no write),
SkinBuilder grid/table/unknown refusal + no file written, list/form
unchanged.

## Exit-criteria verification (real runs, this session)

1. `zfa tdd view` on a scratch 004-login-ui fixture (adaptive_layouts:
   mobile, macos) → output carries BOTH `<View>MobileLayout` and
   `<View>MacosLayout` stubs + slot keys (EC-1).
2. Plan run on the same fixture → `typed-ledger.md` carries the
   per-layout heatmap; `XrayLedgerOverlay.renderPlatformHeatmap`
   renders it (EC-2).
3. Vocabulary-gate + SkinBuilder refusals prove no unchecked grid/table
   emission (EC-3).

Verification artifacts: `tdd/test-list.md` (behaviors BEFORE
implementation), `tdd/verification.md` (from the real runs — analyze +
test counts, exit-criteria proofs), both committed.
