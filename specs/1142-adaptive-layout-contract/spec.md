# Feature Specification: Adaptive layout contract — tdd view emits per-platform stubs, ledger traces per platform

**Issue:** [#1142](https://github.com/arrrrny/zuraffa/issues/1142) · **Part of:** #1134 (EPIC 3: Presentation) · **Extends:** #1004 (Skin Contract — adaptive slots), #1102 (Runtime skin contract auditor) · **References:** #939 (the view-builder surface), #963/#1141 (the UI surface ledger), #1005 (the SkinEvent stream)

## Summary

`zfa tdd view` generates a single-layout `StatelessWidget` `Column`. The production ZikZak login is an `AdaptiveViewState` with separate mobile and macos layout widgets — a machine-generated view is structurally different from the real product it is supposed to seed. This spec makes the adaptive shape a DECLARED contract and makes its coverage honest:

1. **Spec contract** — the Presentation table declares the platform layout slots per feature (an `adaptive_layouts` bullet), the same declaration surface the #1004 skin contract and the i18n `key:` contract ride.
2. **`zfa tdd view` emits an `AdaptiveViewState` skeleton** with one per-platform layout stub per declared slot (mobile, macos), each stub carrying the composed scenario surfaces plus a TODO placeholder matching the `adaptive_layout_scaffold_builder` pattern.
3. **Each platform layout is traced independently in the coverage ledger** — a "mobile-only 100% traced" login is still missing macOS coverage (the exact blind spot the #1102 pilot caught live).
4. **The ledger renders per-platform kind-coverage as a heatmap** (kind × slot `traced/total` cells).

A feature that declares no slots keeps the single-layout skeleton byte-for-byte — zero drift.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — the Presentation table declares platform layout slots (Priority: P1)

**Given** a spec whose Presentation layer contract carries an `adaptive_layouts` bullet naming the slots (`mobile`, `macos`), **When** plan/view read the layer contracts, **Then** the declaration parses into the platform layout contract; an unknown slot name refuses BY NAME with a `--> fix:` line before any artifact is written (errors-are-an-API).

#### Acceptance Scenarios

1. **Given** `- \`adaptive_layouts\`: \`mobile\`, \`macos\`` under `### Presentation`, **When** parsed, **Then** the contract carries `['mobile', 'macos']` in declaration order, de-duplicated.
2. **Given** the same bullet under `### Domain`, **When** parsed, **Then** the contract is null (only Presentation declares layout slots).
3. **Given** a slot token outside the known vocabulary (`pocketwatch`), **When** plan or view runs, **Then** the command refuses (plan: exit 2 pre-artifact; view: exit 1 pre-write) naming the token and the known slots.

### User Story 2 — `zfa tdd view` emits the AdaptiveViewState skeleton (Priority: P1)

**Given** a widget behavior whose feature declares slots, **When** `zfa tdd view` scaffolds, **Then** the subject carries a `StatefulWidget` + `_<View>State` whose `_resolveSlot` mirrors the production login (phone-width → narrow slot; wider surfaces branch on the host platform, declared slots only), one branch per slot with a per-slot key (`<snake>-slot-<slot>`), and one layout stub class per declared slot. Each stub composes the SAME declared surfaces (scenario literals + Presentation component stand-ins) so the paired test can flip green on every slot, plus the `Text('TODO: Implement <view> <slot> layout')` placeholder following the `adaptive_layout_scaffold_builder` pattern. Slot declaration tokens never render as component stand-ins. The skeleton is deterministic (identical inputs → identical bytes) and the view-builder function name is preserved (044 ownership).

#### Acceptance Scenarios

1. **Given** slots `[mobile, macos]`, **When** the view scaffolds, **Then** both `A001ViewMobileLayout` and `A001ViewMacosLayout` exist with per-slot keys and the scaffold-builder TODO placeholders.
2. **Given** a feature with no slot declaration, **When** the view scaffolds, **Then** the output is the single-layout skeleton (zero drift, byte-identical semantics).
3. **Given** the same stub + contract twice, **When** the view re-runs, **Then** the rendered adaptive skeleton is byte-identical.

### User Story 3 — per-platform ledger coverage + heatmap (Priority: P1)

**Given** the declared surfaces (the #1141 projection) and the declared slots, **When** the platform coverage ledger derives, **Then** every surface × slot combination is a row whose state is DONE iff a green prover of the surface EXERCISED that slot (the #1005 SkinEvent stream: `skin-event: behavior=X slot=Y`); plan-time (no evidence) renders every per-slot row NOT-DONE — visible, never omitted. The ledger artifact renders the per-platform section plus the kind × slot heatmap.

#### Acceptance Scenarios

1. **Given** an aggregate 100% green ledger whose only prover emitted `slot=mobile` events, **When** the platform ledger derives, **Then** mobile rows are DONE and macos rows stay NOT-DONE — the aggregate never masks the macOS gap.
2. **Given** the derived platform rows, **When** the heatmap renders, **Then** one row per kind carries `traced/total` per slot (`| text | 1/1 | 0/1 |`).

## Functional Requirements

- **FR-001**: The system shall parse the Presentation layer contract's `adaptive_layouts` bullet (aliases: `platform_layouts`, `platform_slots`) into the typed platform layout contract, refusing unknown slot names by name; only Presentation-layer bullets contribute.
- **FR-002**: The system shall emit, for features declaring slots, an AdaptiveViewState skeleton with one layout stub per declared slot, each stub composing the declared surfaces and the adaptive_layout_scaffold_builder TODO placeholder, keyed per slot; features declaring no slots keep the single-layout skeleton.
- **FR-003**: The system shall trace each declared platform slot independently in the coverage ledger (surface × slot rows, SkinEvent evidence recomputed at read time) and render the per-platform kind-coverage heatmap into the ledger artifacts.

## Success Criteria

- **SC-001**: `zfa tdd view` for a feature declaring `[mobile, macos]` emits both layout stubs with per-slot keys and TODO placeholders (test: `spec_1142_adaptive_layout_test.dart` U-1142-1/U-1142-2).
- **SC-002**: The ledger shows coverage per platform, not just aggregate — a mobile-only prover set leaves macos NOT-DONE with the heatmap naming the gap (U-1142-6/U-1142-7/U-1142-8).
- **SC-003**: The generated AdaptiveViewState compiles (Flutter-analyzer clean on a scratch Flutter host — see verification.md for the exact command and result).
- **SC-004**: Zero drift — features without the declaration keep the single-layout skeleton (U-1142-4), and the full affected suite passes with no new failures vs master.
