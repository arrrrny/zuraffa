# Feature Specification: 1134-presentation-contracted-views — EPIC 3: Presentation (contracted views + adaptive layouts + coverage ledger)

**Feature Branch**: `feat/1134-presentation-contracted-views`

**Created**: 2026-09-18

**Status**: Approved (epic issue #1134, priority high; extends #1004, #1102; merges #963 + #966)

**Input**: Epic issue #1134 — "`zfa tdd view` generates deterministic,
machine-checkable views that support platform layouts (iOS/Android/macOS).
Handwritten view code is tracked by receipt. The coverage ledger is typed,
not just present."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Adaptive layout contract (Priority: P1)

A spec author declares platform layout slots (Presentation
`adaptive_layouts` bullet, issue #1142 — and, when the spec declares a
`## Skin Contract` (issue #1004) but no Presentation bullet, the CONTRACT's
`adaptive_slots` drive the skeleton). `zfa tdd view` emits the
`AdaptiveViewState` skeleton with one layout stub per declared slot —
mobile AND macos in the same generated output — and every declared layout
slot is traced independently in the coverage ledger: a mobile-only prover
set leaves the macos rows untraced, visible, never omitted.

**Why this priority**: The production login is `AdaptiveViewState` with
mobile + macOS; a generator that emits single-layout Columns is
structurally different from the product it claims to certify. This is the
epic's first exit criterion (004-login-ui: mobile + macOS slots in the
same generated output).

**Independent Test**: Run `zfa tdd view` on a stubbed widget behavior of
a feature declaring `adaptive_layouts: mobile, macos` (004-login-ui) and
assert the generated output carries BOTH the `<View>MobileLayout` and
`<View>MacosLayout` stubs with their slot keys; run `zfa tdd plan` and
assert the ledger's per-platform section names both slots.

**Acceptance Scenarios**:

1. **Given** a feature whose Presentation contract declares
   `adaptive_layouts: mobile, macos` and a widget behavior with an
   UnimplementedError stub, **When** `zfa tdd view <id>` runs, **Then**
   the emitted subject is a StatefulWidget with `_resolveSlot` and TWO
   layout stubs (`<View>MobileLayout`, `<View>MacosLayout`), each
   carrying its slot key (`<snake>-slot-mobile`, `<snake>-slot-macos`).
2. **Given** a feature that declares `## Skin Contract` with
   `adaptive_slots: [mobile, ios, android, macos]` but NO Presentation
   `adaptive_layouts` bullet, **When** `zfa tdd view` runs on a widget
   behavior, **Then** the skeleton honors the CONTRACT's slots (the #1004
   declaration drives generation — one declaration, one skeleton).
3. **Given** a feature declaring no slots anywhere, **When**
   `zfa tdd view` runs, **Then** the single-layout skeleton is emitted
   unchanged (zero drift for every existing feature).
4. **Given** the per-platform ledger, **When** a surface's green provers
   exercised only the mobile slot, **Then** the macos row of that surface
   reads untraced (each layout traced independently).

---

### User Story 2 — View pipeline cleanup (Priority: P2)

The two view generators (`zfa view` — dynamic, mock-probed;
`zfa tdd view` — deterministic, machine-contracted) are FENCED: neither
silently clobbers the other's output, and the mainline `zfa view` ported
the deterministic contract — the `already-implemented` verdict (an
existing view is reported as already implemented, nothing scaffolded,
exit 0) and the machine summary line (`view: entity=… outcome=…`).

**Why this priority**: Two generators sharing zero code with different
honesty disciplines is the epic's stated "current state" problem; the
resume/idempotency contract of the mainline generator is what pipelines
grep for.

**Independent Test**: Run `zfa view create Login` twice — the second run
prints `already implemented — nothing to scaffold` and the machine line
`view: entity=Login outcome=already-implemented` (exit 0); run it against
a file carrying the `zfa tdd view` subject marker and it refuses (the
fence) naming the other generator.

**Acceptance Scenarios**:

1. **Given** no existing view file, **When** `zfa view create <Entity>`
   runs, **Then** the view is scaffolded and the machine summary line
   `view: entity=<Entity> outcome=scaffolded files=<n>` prints.
2. **Given** an existing generator-written view file and no `--force`,
   **When** `zfa view create <Entity>` runs again, **Then** the run
   reports `already implemented — nothing to scaffold`, prints
   `view: entity=<Entity> outcome=already-implemented`, and exits 0 —
   the deterministic contract (same inputs, same bytes, same verdict).
3. **Given** a target file carrying the `zfa tdd view` subject marker
   (the other generator's output), **When** `zfa view create` runs
   without `--force`, **Then** the run refuses (exit 1) naming the tdd
   generator and the `--force` escape — the fence, never a silent
   clobber.
4. **Given** a target file with NEITHER generator marker (hand-written
   code, the #1005 seam tracked by receipt), **When** `zfa view create`
   runs without `--force`, **Then** the run reports already-implemented
   (hand-written views are never silently overwritten).

---

### User Story 3 — Typed UI coverage ledger (Priority: P1)

`zfa tdd plan` derives the TYPED ledger (merging #963's surface ledger
with #966's typed rows): every row is (surface, kind:
`presence|absence|navigation|state|sequence`, status:
`traced|untraced`), written to `tdd/typed-ledger.md` +
`tdd/typed-ledger.json` alongside the 075 ledger. When the feature
declares platform layout slots, the ledger carries the PER-LAYOUT
kind-coverage heatmap (kind × slot), and the XRay overlay binding
renders kind coverage per layout — not just a surface count.

**Why this priority**: Presence-only ledgers are gameable (the #966
demonstration: an all-literals Column posts 9/9 while the app is wrong
three ways); typed rows + the per-layout heatmap are the epic's second
exit criterion.

**Independent Test**: Run `zfa tdd plan` on a feature with widget
behaviors (all five kinds reachable) and assert `typed-ledger.md` rows
carry the five-kind vocabulary with `traced|untraced` status in the JSON;
assert the per-layout heatmap section names every declared slot; assert
`XrayLedgerOverlay` renders the per-layout kind-coverage lines.

**Acceptance Scenarios**:

1. **Given** a feature with widget behaviors whose scenarios use the
   finder-kind verbs (shows / is not shown / navigates to / is disabled /
   while…in flight), **When** `zfa tdd plan` runs, **Then**
   `tdd/typed-ledger.md` + `tdd/typed-ledger.json` are written with one
   row per declared surface, kind from the scenario verb taxonomy
   (presence / absence / navigation / state / sequence) and status
   `traced|untraced` (plan-time: untraced, visible, never omitted).
2. **Given** a feature declaring `adaptive_layouts: mobile, macos`,
   **When** `zfa tdd plan` runs, **Then** the typed ledger carries a
   per-layout kind-coverage heatmap — one row per kind, one cell per
   declared slot, each cell `traced/total`.
3. **Given** the typed ledger rows and declared slots, **When** the XRay
   overlay binding renders, **Then** it renders PER-LAYOUT kind coverage
   (a line per kind × slot with HIGHLIGHT on zero-traced cells) — kind
   coverage, not surface count.
4. **Given** the control deck binding, **When** the deck lists platform
   entries, **Then** each (slot, kind) cell appears with a traced/untraced
   badge.
5. **Given** a plan-time run, **When** no green evidence exists yet,
   **Then** every row reads untraced — the artifact is the DECLARED
   inventory; state recomputes at read time (a stored state is a cache,
   never the truth).

---

### User Story 4 — shadcn vocabulary as TDD gate (Priority: P1)

`zfa tdd plan` validates widget references (Presentation component
tokens) against the `zfa ui schema` vocabulary (the `NodeRegistry`
built-ins + project composites); `zfa tdd view` enforces the same gate
before any write; the skin builder's silent grid/table→list fall-through
is REMOVED — `grid`/`table` are not in the vocabulary, are not
implemented, and every generator refuses them BY NAME.

**Why this priority**: "shadcn grid/table silently falls through to list —
lying generator" is the epic's named defect; the vocabulary gate is the
third exit criterion (no view generator emits unchecked grid/table
layout code).

**Independent Test**: A Presentation contract token `ShadGrid` (or
`grid`/`table`) makes `zfa tdd plan` exit 2 naming the token and the
vocabulary fix; `ShadInput`/`ZfaButton` pass (prefix-normalized to
`input`/`button`); `SkinBuilder` with layout `grid` refuses loudly and
writes nothing.

**Acceptance Scenarios**:

1. **Given** a Presentation component token whose normalized name
   (shad/zfa/zuraffa prefix stripped, lowercased) is a `zfa ui schema`
   vocabulary name (`ShadInput` → `input`, `ZfaButton` → `button`),
   **When** `zfa tdd plan` / `zfa tdd view` run, **Then** the token
   passes the gate.
2. **Given** a Presentation component token whose normalized name is NOT
   in the vocabulary (`grid`, `table`, `ShadGrid`), **When**
   `zfa tdd plan` runs on a feature with widget behaviors, **Then** the
   plan refuses (exit 2) naming the token, the vocabulary it must
   declare from, and the `zfa ui schema` fix line.
3. **Given** the same offending token, **When** `zfa tdd view` runs,
   **Then** the view refuses BEFORE any write (exit 1) — no unchecked
   layout code is emitted.
4. **Given** `SkinBuilder.generate` with `layout: grid` (or `table` or
   any unknown layout), **When** it runs, **Then** it refuses BY NAME
   (grid/table are not implemented and not in the vocabulary) and writes
   NO file — the silent fall-through to the list template is gone.
5. **Given** a method-signature component token (`buildMain(a, b) ->
   String`) or a `key:` token, **When** the gate validates, **Then**
   these are not widget references and never refuse (library-dev
   contracts stay untouched).

## Functional Requirements

- **FR-001**: The system shall emit the `AdaptiveViewState` skeleton
  (StatefulWidget + `_resolveSlot` + one layout stub per declared slot)
  from the Presentation `adaptive_layouts` declaration, falling back to
  the `## Skin Contract` `adaptive_slots` when no Presentation bullet
  declares slots, and emitting the single-layout skeleton when neither
  exists (zero drift).
      traces: adaptive_layouts
- **FR-002**: The system shall report, on the mainline `zfa view`, the
  deterministic contract: `already-implemented` verdict for existing
  subjects (exit 0, nothing scaffolded) and the machine summary line
  `view: entity=<n> outcome=<scaffolded|already-implemented|error>` on
  every outcome.
      traces: view_pipeline_contract
- **FR-003**: The system shall fence the two view generators: the
  mainline generator refuses (exit 1, naming the other generator and the
  `--force` escape) to scaffold over a `zfa tdd view` subject marker;
  hand-written files (no marker) report already-implemented without
  `--force`.
      traces: view_pipeline_fence
- **FR-004**: The system shall derive the typed ledger at plan time —
  one row per declared surface, kind assigned from the scenario verb
  taxonomy (presence|absence|navigation|state|sequence), status
  `traced|untraced` — and write `tdd/typed-ledger.md` +
  `tdd/typed-ledger.json`.
      traces: typed_ui_ledger
- **FR-005**: The system shall render the per-layout kind-coverage
  heatmap (kind × declared slot) into the typed ledger and the XRay
  overlay binding (kind coverage per layout, HIGHLIGHT on zero-traced
  cells; deck entries per (slot, kind)).
      traces: typed_ui_ledger
- **FR-006**: The system shall validate Presentation widget references
  against the `zfa ui schema` vocabulary at plan time (exit 2 refusal
  naming the token + fix) and at view time (refusal before any write).
      traces: ui_vocabulary_gate
- **FR-007**: The system shall refuse unknown layouts in the skin
  builder BY NAME (grid/table not implemented, not in the vocabulary)
  and never silently fall through to the list template.
      traces: ui_vocabulary_gate

## Layer Contracts

**Presentation**:

- `WidgetVocabularyGate`: `normalize(token) -> vocabulary name?`, `validate(tokens) -> violations`
- `TypedLedgerProjection`: `declaredRows(behaviors, components, keys, slots) -> DeclaredLedgerRow list`
- `ViewGenerationContract`: `inspect(path, content) -> notFound|generatorWritten|tddSubject|handWritten`, `machineSummary(entity, outcome, files) -> String`

**Domain**:

- `PlatformLayoutContract`: `resolve(contracts, skinContract) -> PlatformLayoutContract?`
- `TypedPlatformLedger`: `derive(rows, slots, evidence) -> per-slot typed rows`, `kindSlotHeatmap(rows, slots) -> String`
- `TypedLedgerBuilder`: `derive(declared, green) -> rows`, `toMarkdown/toJson(rows) -> artifacts`

## Non-Functional Requirements

- Determinism: same declared inputs render the same output bytes and the
  same machine summary line (no timestamps, no environment leakage).
- Zero drift: features declaring no slots keep byte-identical generated
  views; the 075 `ui-ledger.{md,json}` artifacts keep their pinned shape
  (the typed ledger is a NEW artifact pair).
- Errors-are-an-API: every refusal names the offending token/shape and
  the `--> fix:` line; refusals write NOTHING.
- Constitution VII (Engine Purity): all new library code is pure Dart.

## Exit Criteria (epic #1134)

1. 004-login-ui: view supports mobile and macOS layout slots in the same
   generated output.
2. XRay overlay shows a per-layout kind-coverage heatmap.
3. No view generator emits unchecked `grid`/`table` layout code.
