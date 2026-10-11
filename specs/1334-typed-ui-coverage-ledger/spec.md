# Feature Specification: typed UI coverage ledger — every row has a kind, not just a presence flag

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1143-typed-ui-coverage-ledger`

**Created**: 2026-09-09

**Status**: Draft

**Input**: GitHub issue #1143 (ZIKZAK-REBUILD, EPIC 3: Presentation) — "typed UI coverage ledger — every row has a kind, not just a presence flag". Extends #963 (XRay gatekeeper / 075-ui-coverage-ledger) and #966 (0966-typed-ledger-rows); composes with #964 (finder-kind taxonomy).

## Problem

The coverage ledger counts **presence only**. A view that renders ALL text at once, navigates nowhere, and never disables anything posts **100% traced** — the ledger is trivially satisfiable. This is gaming: the ledger says complete while the app is wrong in every way a user would notice (error banner permanently visible, buttons never disabled, no interaction chains, no route outcomes).

Spec 0966 (issue #966) introduced typed rows, but the composed #1143 contract is tighter than what landed:

1. The shipped `LedgerRowKind` carries a **sixth** `golden` value — the issue pins the kind vocabulary at **five** (presence, absence, navigation, state, sequence); a golden row is a *presence* row with an `advisory: true` flag.
2. The per-screen coverage report still lists **declared** kinds only. A screen whose plan declared presence rows only (the gaming shape) has zero rows of the other kinds and reads clean — exactly the "not 100%" clause AC-2 forbids: *any* kind with zero traced rows for a screen is a gap.
3. The XRay overlay still renders the **surface-count** view (`paint`/`highlights` over `UiSurfaceRow`) for typed ledgers; the per-kind breakdown per screen is additive, not the view.
4. A ledger JSON **without kind fields** (the 075 shape) cannot be read by the typed pipeline at all — no legacy mode, so the tightened gate would break existing projects on day one (AC-6).

## Proposal

- **Five kinds, exactly.** `LedgerRowKind` = `presence | absence | navigation | state | sequence`. Golden (visual regression) is not a kind: a golden row carries `kind: presence` + `advisory: true` + per-platform tolerance and stays out of the merge gate (flaky economics on Intel CI — recorded decision from #966, kept).
- **Per-screen kind report.** For every screen the coverage report lists **all five kinds** with traced/total counts (0/0 included). A kind with zero traced rows is a gap for that screen — declared or not. A presence-only screen reads `partially-traced`, never 100%.
- **Per-kind overlay replaces surface-count.** The XRay overlay for typed ledgers renders the per-kind breakdown per screen (status line + one line per kind, untraced kinds highlighted, never painted as proof). The legacy `paint`/`highlights` surface-count view remains only for legacy (kindless) ledgers.
- **Legacy mode.** Ledger JSON whose rows carry no typed kind label (the 075 `text/route/affordance/key` shape, or no kind field) is reclassified row-by-row to `presence` and evaluated **rows-only**: no kind gaps, no per-screen tightening. The gate does not break existing projects — it only tightens coverage requirements for new typed ledgers.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The gaming view can no longer post 100% (Priority: P1)

A login screen whose ledger holds presence rows only (all traced green) must read **partially traced** — absence, navigation, state, and sequence each show `0/N` (or `0/0`) as gaps, and the per-screen gate fails naming the kinds. The all-9-literals-`Column` demo (renders everything, navigates nowhere, disables nothing) is the canonical gaming fixture.

**Why this priority**: This is the entire point of the issue — the ledger is trivially satisfiable today; without this slice nothing else matters.

**Independent Test**: Derive the gaming ledger for `/login`, run the per-screen gate: verdict fails, `kindGaps` names the four untraced kinds, overlay renders `partially-traced`.

**Acceptance Scenarios**:

#### Scenario 1.1 — presence-only screen is partially traced (AC-2)

```gherkin
Given a ledger for screen "/login" whose rows are 9 presence rows, all traced green
When the per-screen kind report is derived
Then all five kinds are listed (presence 9/9, absence 0/0, navigation 0/0, state 0/0, sequence 0/0)
And every kind with zero traced rows is a gap
And the screen status is "partially-traced" — not 100%
```

**Type**: unit (pure model: `TypedLedgerBuilder` + `ScreenKindReport`)

#### Scenario 1.2 — the per-screen gate fails the gaming ledger (AC-2)

```gherkin
Given the same gaming ledger for "/login"
When the typed per-screen gate evaluates it
Then the verdict fails with kind gaps naming absence, navigation, state, and sequence
And the failure lines carry fix hints
```

**Type**: unit (pure model: `TypedCoverageGate.evaluateScreens`)

#### Scenario 1.3 — the honest five-kind screen passes (AC-2)

```gherkin
Given the honest "/login" ledger with presence, absence, navigation, state, and sequence rows all traced green
When the per-screen gate evaluates it
Then the screen status is "fully-traced" and the aggregate verdict passes
```

**Type**: unit

### User Story 2 - Golden rows are advisory presence rows (Priority: P1)

A visual-regression (golden) row declared with per-platform tolerance carries `kind: presence` + `advisory: true`; it never blocks the merge gate regardless of state, and the verdict/deck report it separately with its tolerance.

**Why this priority**: AC-5 is a data-model correction (golden is a flag, not a kind) that unblocks the five-kind vocabulary; also keeps the Intel-CI flaky-economics decision intact.

**Independent Test**: Declare a golden scenario, derive, evaluate: kind is presence, advisory true, gate passes with the golden unproven, deck reports `ADVISORY` with `android: ±1.0px`.

**Acceptance Scenarios**:

#### Scenario 2.1 — a golden scenario yields an advisory presence row (AC-5)

```gherkin
Given a scenario "the login view matches the golden snapshot on every platform" with per-platform tolerance {ios: 0.5, android: 1.0, web: 2.0}
When the plan derives its ledger row
Then the row's kind is presence (never a sixth "golden" kind) and advisory is true
And the tolerance is carried on the row and rendered in the artifacts
```

**Type**: unit

#### Scenario 2.2 — goldens never block the merge gate (AC-5)

```gherkin
Given a ledger whose gate rows all trace green and whose golden row has no prover at all
When the gate evaluates it
Then the verdict passes, the golden row is reported in the advisory section, and the kind coverage does not count it
```

**Type**: unit

### User Story 3 - The overlay renders kind coverage per screen (Priority: P2)

The XRay overlay for a typed ledger renders, per screen: a status line (`fully-traced` / `partially-traced` / `untraced`) plus one line per kind with traced/total; untraced kinds are highlighted, never painted as proof. The surface-count view remains only for legacy ledgers.

**Why this priority**: The overlay is where humans see the gaming; it composes with #963 (XRay gatekeeper) and feeds the control deck.

**Independent Test**: Render `/login` (gaming) and `/deal_list` (fully traced): the first shows `partially-traced` with highlighted kind lines, the second `fully-traced` with all five kinds clean.

**Acceptance Scenarios**:

#### Scenario 3.1 — per-kind rendering replaces the surface-count view (AC-3)

```gherkin
Given a typed ledger grouped by screen
When the overlay renders a screen
Then the rendering is the per-kind breakdown (status + one line per kind with traced/total), not a surface count
And zero-traced kinds are marked HIGHLIGHT
```

**Type**: unit

#### Scenario 3.2 — a screen next to a fully traced one is distinguishable (AC-3)

```gherkin
Given "/login" partially traced and "/deal_list" fully traced
When the overlay renders both screens
Then their status lines differ and each screen's kind lines carry its own counts
```

**Type**: unit

### User Story 4 - Kinds are assigned at plan time and consumed verbatim (Priority: P2)

The finder-kind taxonomy (#964) assigns kinds at plan time from the spec's scenario verbs; the ledger consumes these assignments — it never re-infers a kind post hoc, and a row whose kind came from the plan survives derivation verbatim.

**Why this priority**: Plan-time assignment is the anti-gaming seam — a view cannot re-label a row to dodge a kind gap.

**Independent Test**: Declare rows via `fromScenario` (verb-derived) and rows with an explicit plan kind; after derivation every row keeps its plan-time kind.

**Acceptance Scenarios**:

#### Scenario 4.1 — scenario verbs decide the kind at plan time (AC-4)

```gherkin
Given scenarios carrying a hidden verb, a navigation verb, an attribute verb, a chain, and a render verb
When the plan derives their rows
Then the kinds are absence, navigation, state, sequence, and presence respectively — never flattened to presence
```

**Type**: unit

#### Scenario 4.2 — the ledger consumes plan-time assignments verbatim (AC-4)

```gherkin
Given a declared row whose kind the plan assigned explicitly (not from verbs)
When the ledger derives rows
Then the row carries exactly that kind — the ledger does not re-infer or relabel it
```

**Type**: unit

### User Story 5 - Legacy ledgers keep working (Priority: P1)

An existing 075-shaped ledger JSON (rows with `text/route/affordance/key` kind labels or no kind label at all) is read row-by-row, reclassified to presence, and evaluated rows-only: the gate does not break existing projects — it only tightens coverage requirements for new typed ledgers.

**Why this priority**: AC-6 — without legacy mode, every existing project goes red the moment the typed gate ships.

**Independent Test**: Parse a 075 ledger JSON (all rows green) → legacy verdict passes with zero kind gaps; parse the same ledger with one red row → verdict fails on the row gap only.

**Acceptance Scenarios**:

#### Scenario 5.1 — kindless rows are reclassified presence (AC-1, AC-6)

```gherkin
Given a 075-shaped ledger JSON whose rows carry kind labels text/route/affordance/key and no typed kind field
When the typed pipeline reads it
Then every row is reclassified as a presence row and the parse reports legacy mode
```

**Type**: unit

#### Scenario 5.2 — the legacy gate is rows-only (AC-6)

```gherkin
Given a legacy ledger whose rows are all green
When the gate evaluates it
Then the verdict passes (legacy mode: no kind gaps, no per-screen tightening)
And a legacy ledger with one red row fails on that row gap only
```

**Type**: unit

#### Scenario 5.3 — a 0966-written ledger with golden rows reads as typed (AC-6)

```gherkin
Given a ledger JSON written by the 0966 pipeline whose golden rows carry kind "golden"
When the typed pipeline reads it
Then those rows are reclassified presence + advisory true and the ledger is typed (not legacy)
```

**Type**: unit

### User Story 6 - The typed ledger row carries exactly five kinds (Priority: P1)

Every coverage ledger row carries a `kind` field with one of exactly five values; the existing presence-only rows are reclassified as `presence`.

**Why this priority**: AC-1 — the vocabulary fix is the data-model foundation for everything above.

**Independent Test**: `LedgerRowKind.values` has exactly 5 entries; every derived row's kind is one of them; golden rows are presence+advisory.

**Acceptance Scenarios**:

#### Scenario 6.1 — five kinds, no sixth (AC-1)

```gherkin
Given the LedgerRowKind vocabulary
When inspected
Then it contains exactly presence, absence, navigation, state, sequence — and no golden value
```

**Type**: unit

#### Scenario 6.2 — presence-only rows reclassify as presence (AC-1)

```gherkin
Given legacy presence-only rows (the 075 shape)
When reclassified into the typed model
Then every row's kind is presence
```

**Type**: unit

## Requirements

- **FR-001 (AC-1)**: Every coverage ledger row MUST carry a `kind` field with one of exactly five values — `presence`, `absence`, `navigation`, `state`, `sequence`. `LedgerRowKind` MUST expose exactly these five values; existing presence-only rows are reclassified as the `presence` kind.
- **FR-002 (AC-5)**: Golden (visual-regression) rows MUST NOT be a sixth kind: their kind MUST be `presence` with an `advisory: true` flag and per-platform tolerance, and they MUST stay out of the merge gate (recorded decision: flaky economics on Intel CI), reported separately in the verdict and the deck.
- **FR-003 (AC-2)**: For every screen, the per-screen kind report MUST list all five kinds with traced/total counts (including `0/0`), and ANY kind with zero traced rows MUST be counted as a gap — a screen with only presence rows shows as `partially-traced`, never 100%.
- **FR-004 (AC-2)**: The per-screen gate MUST fail when any screen has a row gap or any zero-traced kind gap, naming each gap with a fix hint; it MUST pass only when every screen is `fully-traced` (all five kinds have ≥ 1 traced row and every gate row is DONE).
- **FR-005 (AC-3)**: The XRay overlay MUST render kind coverage per screen — a status line plus a traced/total breakdown per kind — replacing the surface-count view for typed ledgers; zero-traced kinds are highlighted, never painted as proof. The legacy surface-count view remains available only for legacy (kindless) ledgers.
- **FR-006 (AC-4)**: Kinds MUST be assigned at plan time (the finder-kind taxonomy #964 — scenario verbs decide: hidden → absence, navigation → navigation, attribute → state, chain → sequence, default render → presence) and the ledger MUST consume these assignments verbatim — never re-inferred post hoc, never relabeled.
- **FR-007 (AC-6)**: Ledger JSON without typed kind fields MUST be read in legacy mode: rows reclassified to presence, gate evaluated rows-only (no kind gaps, no per-screen tightening). The gate MUST NOT break existing projects; it only tightens coverage requirements for new typed ledgers. A ledger carrying any typed kind label (including the 0966 `golden` label, reclassified presence+advisory) is typed, not legacy.
- **FR-008 (hard constraint)**: Only the coverage ledger data model, the XRay overlay rendering, and the gate logic may change. The spec format, the test runner, the proof chain, and the existing finder taxonomy (`UiSurfaceKind`) MUST NOT change. Goldens MUST NOT become blocking.

## Success Criteria (measurable)

| # | criterion | measure |
|---|-----------|---------|
| S1 | five kinds exactly | `LedgerRowKind.values.length == 5`, no `golden` value |
| S2 | presence-only screen not 100% | gaming `/login` fixture → status `partially-traced`, 4 zero-traced kind gaps, per-screen gate fails |
| S3 | honest five-kind screen passes | honest `/login` fixture → status `fully-traced`, aggregate verdict `passed == true` |
| S4 | golden advisory | golden row kind == presence, advisory == true, tolerance carried; gate passes with golden unproven; deck reports ADVISORY |
| S5 | per-kind overlay rendering | rendered lines = status + per-kind `traced/total` per screen; zero-traced kinds marked HIGHLIGHT; surface-count view legacy-only |
| S6 | plan-time kinds consumed verbatim | verb matrix (absence/navigation/state/sequence/presence) + explicit-kind row survives derivation verbatim |
| S7 | legacy mode | 075-shaped JSON → all rows presence, verdict rows-only, all-green passes, one-red fails on row gap only; no kind gaps in legacy mode |
| S8 | no regressions | 0966 + 075 ledger subject suites green after the golden-kind reclassification; `dart analyze` no new issues; `dart format .` zero diff |

## Out of scope

- The spec format, the test runner, the proof chain, the finder taxonomy (`UiSurfaceKind`), the CLI surface — untouched.
- Making goldens blocking — explicitly forbidden (flaky economics on Intel CI; recorded decision).
- The 075 `CoverageGate`/`UiLedgerBuilder` legacy pipeline internals — unchanged (legacy mode reads their JSON shape, does not modify them).
