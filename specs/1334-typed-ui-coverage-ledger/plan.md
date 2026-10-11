# Implementation Plan: 1334-typed-ui-coverage-ledger

**Issue**: arrrrny/zuraffa#1143 · **Extends**: #963 (075), #966 (0966) · **Composes with**: #964 (finder-kind taxonomy) · **EPIC 3**: Presentation (ZIKZAK-REBUILD)

## Summary

Tighten the typed UI coverage ledger to the #1143 contract: exactly five row kinds (presence, absence, navigation, state, sequence — golden becomes `presence` + `advisory: true`), a per-screen kind report that lists all five kinds and counts zero-traced kinds as gaps (a presence-only screen is `partially-traced`, never 100%), a per-kind XRay overlay rendering that replaces the surface-count view for typed ledgers, and a legacy mode so kindless (075-shaped) ledgers keep evaluating rows-only — the gate does not break existing projects.

## Technical Context

### Coverage ledger data model (`lib/src/tdd/services/typed_ledger_row.dart`)

The single source of the typed ledger model, landed by 0966 (issue #966). The #1143 changes:

1. **`LedgerRowKind` — five values exactly.** Remove the `golden` value; keep kebab `label`s. Golden detection moves to `LedgerRowKind.isGoldenScenario(String)` (the plan-time verb pattern, unchanged regex) so `DeclaredLedgerRow.fromScenario` can set `advisory: true` + tolerance for visual-regression scenarios while the row kind reads `presence`. `fromScenarioVerb` maps golden scenarios to `presence` (a golden scenario is a render-matches-snapshot assertion — presence-shaped, advisory-flagged).
2. **`DeclaredLedgerRow` / `TypedLedgerRow` gain `screen`** (default `''`) — the per-screen grouping key for the #1143 report/overlay/gate; carried through `derive`, `toJson`, markdown.
3. **`KindCoverage` gains `zeroTraced`** (`traced == 0`) — the #1143 gap predicate, distinct from the 0966 `untraced` (`total > 0 && traced == 0`) which stays for the feature-wide declared-kinds view (0966 contract, unchanged).
4. **`TypedLedgerBuilder.kindCoverageAllKinds(rows, {screen})`** — NEW: one `KindCoverage` for EVERY of the five kinds (0/0 included), the per-screen report view.
5. **`TypedLedgerBuilder.groupByScreen(rows)`** — NEW: `Map<String, List<TypedLedgerRow>>`.
6. **`TypedLedgerBuilder.fromLedgerJson(String)`** — NEW: parses a stored ledger JSON (075 or 0966 shape) into rows + a `legacy` flag. Rules: row `kind` in the five labels → typed row (all semantics fields carried); `kind == 'golden'` (0966 artifact) → presence + advisory true; kind missing or a legacy `UiSurfaceKind` label (`text`/`route`/`affordance`/`key`) or unknown → presence reclassification. Ledger is **legacy** iff NO row carried a typed label. State is recomputed at read time (provers + malformed rules), never trusted from the cache.
7. **`ScreenKindReport`** — NEW: screen, all-five-kinds coverage, `status` (`fully-traced` / `partially-traced` / `untraced`), `zeroTracedKinds`, `rowGaps`. Built by `TypedLedgerBuilder.screenReports(Map<String, List<TypedLedgerRow>>)` (or from flat rows via groupByScreen).

### XRay overlay rendering (`lib/src/tdd/services/xray_ledger_binding.dart`)

The #963/#966 binding. The #1143 changes:

1. **`XrayLedgerOverlay.renderScreen(ScreenKindReport)`** — NEW: the per-kind view — a status line (`/login: partially-traced`) + one line per kind (`presence 9/9`, `absence 0/0 HIGHLIGHT` — zero-traced kinds marked, never painted as proof).
2. **`XrayLedgerOverlay.renderByScreen(...)`** — NEW: renders every screen.
3. **Screen status** — the `fully-traced` / `partially-traced` / `untraced` decision landed MODEL-SIDE as the `ScreenKindReport.status` getter (`fully-traced` iff every kind traced ≥ 1 and no row gaps; `untraced` iff zero traced rows overall), consumed by `XrayLedgerOverlay.renderScreen` and `XrayLedgerDeck.screenEntries`. The originally planned `XrayLedgerOverlay.screenStatus(coverage)` overlay member did not land.
4. **`paint`/`highlights`** stay for the LEGACY surface-count view only (`UiSurfaceRow` — the 075 pipeline; doc-commented as replaced for typed ledgers). The 0966 `kindCoverage`/`kindCoverageByScreen`/`partiallyTraced`/`untracedKindLabels` keep their declared-kinds semantics (0966 subjects pin them).
5. **Deck**: `kindEntries` + `advisoryEntries` unchanged; the golden advisory entry label still reads `(golden: <tolerance>)` — golden-ness is now the advisory flag, the label describes it.

### Gate logic (`typed_ledger_row.dart` — `TypedCoverageGate`)

1. **`TypedCoverageGate.evaluateScreens({feature, ledgerByScreen})`** — NEW: the #1143 per-screen gate. Per screen: row gaps (NOT-DONE rows) + zero-traced kind gaps (all five kinds). Aggregate `TypedScreensVerdict`: passed iff every screen has no gaps (and the ledger is not legacy). Failure lines name screen + kind + fix hint.
2. **Legacy mode**: a legacy ledger (all rows reclassified presence, `legacy == true`) evaluates rows-only — no kind gaps, no per-screen tightening (AC-6). The feature-wide `TypedCoverageGate.evaluate` (0966 API) keeps its declared-kinds semantics for typed rows; a legacy flag on the verdict exempts kind gaps for legacy input.
3. **`TypedCoverageVerdict`** gains `legacy` (serialized in `encode()` when true) — `passed` = row gaps empty AND (legacy OR no untraced declared kinds).

### Finder-kind taxonomy (#964) — composition, unchanged

`UiSurfaceKind` (`ui_ledger_builder.dart`) and the scenario-verb classifier (`fromScenarioVerb`) are the plan-time assignment seam. The ledger consumes assignments verbatim: `DeclaredLedgerRow.kind` comes from the plan (verb-derived or explicit); `derive` never re-infers. **No changes to `ui_ledger_builder.dart`, `coverage_gate.dart`, or `UiSurfaceKind`.**

### Absence + state assertions (#966) — semantics, unchanged

The kind rules in `derive` (absence needs `notRenderedIn`, sequence needs ≥ 2 `steps`, state needs `attribute`) stay exactly as 0966 landed — the #1143 report/gate/overlay sit on top of them.

## Constitution Check

- **VII (pure Dart, no Flutter)**: the touched services import `dart:convert` only — holds.
- **Honest red / honest green**: every behavior lands red first (`UnimplementedError` or failing pin), then green; mutation-style strength pins (T7 verb matrix precedent) included.
- **State recomputed at read time**: `fromLedgerJson` recomputes row state from provers + malformed rules — a stored state is a cache, never the truth (the #963 discipline).
- **No gate-breaking for existing projects**: legacy mode is a first-class contract (AC-6), tested by 075-shaped JSON fixtures.

## Project Structure

### Documentation (this feature)

```
specs/1334-typed-ui-coverage-ledger/
├── spec.md                     # this feature's contract (6 ACs → FR-001..008, S1..S8)
├── plan.md                     # this file
├── tasks.md                    # dependency-ordered, MVP-first
└── tdd/
    ├── test-list.md            # one behavior per line, traced to ACs
    ├── verification.md         # red/green + mutation evidence
    └── evidence/               # raw red/green run transcripts
```

### Source Code (repository root)

```
lib/src/tdd/services/
├── typed_ledger_row.dart       # CHANGED: 5 kinds, golden→advisory, screen field,
│                               #   kindCoverageAllKinds, groupByScreen,
│                               #   fromLedgerJson (legacy), ScreenKindReport,
│                               #   TypedCoverageGate.evaluateScreens + legacy verdict
├── xray_ledger_binding.dart    # CHANGED: renderScreen/renderByScreen (status rides
│                               #   ScreenKindReport.status); paint/highlights documented legacy-only
├── ui_ledger_builder.dart      # UNCHANGED (finder taxonomy, legacy JSON shape source)
└── coverage_gate.dart          # UNCHANGED (legacy 075 gate)

lib/tdd/1334-typed-ui-coverage-ledger/     # NEW: self-hosting subjects T1–T8
lib/tdd/0966-typed-ledger-rows/            # UPDATED: t6/t7/t8 golden-kind pins →
                                            #   presence+advisory (the 5-kind contract)
test/tdd/1334-typed-ui-coverage-ledger/    # NEW: generated test wrappers
test/tdd/0966-typed-ledger-rows/           # UNCHANGED (wrappers call subjects)
```

## Complexity Tracking

| Category | Count |
|----------|-------|
| FR-001..008 (spec) | 8 |
| New behaviors (subjects) | 8 |
| Files changed (production) | 2 |
| Files changed (self-hosting subjects) | 3 (t6, t7, t8) |
| New files (subjects + tests + artifacts) | 8 subjects + 8 tests + spec artifacts |
