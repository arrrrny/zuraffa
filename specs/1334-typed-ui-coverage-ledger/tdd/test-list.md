# Test List: 1334-typed-ui-coverage-ledger

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Traced to the implementing
behaviors T1–T8 (`test/tdd/1334-typed-ui-coverage-ledger/`).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | every coverage ledger row carries a kind — one of exactly five (presence, absence, navigation, state, sequence); presence-only rows reclassify as presence. | AC-1 (T1, T6) | GREEN |
| A2 | any kind with zero traced rows for a screen counts as a gap in the coverage report; a presence-only screen shows partially traced — not 100%. | AC-2 (T2, T3) | GREEN |
| A3 | the XRay overlay renders kind coverage per screen — status + traced/total per kind — replacing the surface-count view; zero-traced kinds highlight. | AC-3 (T4) | GREEN |
| A4 | kinds are assigned at plan time from the spec's scenario verbs; the ledger consumes the assignments verbatim — never re-inferred post hoc. | AC-4 (T5) | GREEN |
| A5 | golden rows are advisory with per-platform tolerance — kind presence, advisory: true — out of the merge gate, reported separately. | AC-5 (T1) | GREEN |
| A6 | existing ledgers without kind fields are treated as presence-only (legacy mode); the gate does not break existing projects — rows-only, no kind gaps. | AC-6 (T6) | GREEN |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `LedgerRowKind` MUST expose exactly five values (presence, absence, navigation, state, sequence) — no golden kind; a golden scenario yields kind presence + advisory true + tolerance; goldens never block the gate and the deck reports them ADVISORY. | FR-001, FR-002 (T1) | GREEN |
| U2 | the per-screen kind report MUST list all five kinds with traced/total (0/0 included) and count ANY zero-traced kind as a gap; a presence-only screen reads partially-traced. | FR-003 (T2) | GREEN |
| U3 | the per-screen gate MUST fail on row gaps or zero-traced kind gaps (naming screen + kind + fix hint) and pass only when every screen is fully-traced. | FR-004 (T3) | GREEN |
| U4 | the XRay overlay MUST render the per-kind view per screen (status line + one line per kind, zero-traced kinds HIGHLIGHT, never painted as proof); the surface-count view is legacy-only. | FR-005 (T4) | GREEN |
| U5 | kinds MUST be assigned at plan time from scenario verbs and consumed verbatim — the verb matrix holds and an explicitly-kindled plan row survives derivation unchanged. | FR-006 (T5) | GREEN |
| U6 | ledger JSON without typed kind fields MUST read as legacy (rows reclassified presence; gate rows-only — all-green passes, one-red fails on the row gap only); a 0966-written ledger with golden rows reads as typed (presence + advisory). | FR-007 (T6) | GREEN |
| U7 | strength pins: five-kind enumeration, per-screen report shape (status labels, 0/0 entries, HIGHLIGHT polarity), legacy/typed classification, JSON round-trip (screen + advisory survive), zeroTraced vs untraced polarity. | FR-001..007 (T7) | GREEN |
| U8 | verification: format zero-diff, analyze clean on changed files, 1334 + 0966 + 075 ledger suites green (no full suite — cloud budget), mutation-style audit of the zero-traced predicate / legacy classifier / status polarity. | FR-008 (T8) | GREEN |

## Evidence

Red → green recorded per behavior in `tdd/evidence/`:

| behavior | red | green |
| -------- | --- | ----- |
| T1 (five kinds + golden advisory) | `t001-red.txt` (sixth golden kind pin fails) | `t001-green.txt` |
| T2 (all-five-kinds per-screen report) | `t002-red.txt` (ScreenKindReport API missing) | `t002-green.txt` |
| T3 (per-screen gate) | `t003-red.txt` (evaluateScreens API missing) | `t003-green.txt` |
| T4 (per-kind overlay rendering) | `t004-red.txt` (renderScreen API missing) | `t004-green.txt` |
| T5 (plan-time kinds verbatim) | `t005-red.txt` (verb matrix + explicit-kind pins) | `t005-green.txt` |
| T6 (legacy mode) | `t006-red.txt` (fromLedgerJson API missing) | `t006-green.txt` |
| T7 (strength pins) | `t007-red.txt` (pins fail pre-refactor) | `t007-green.txt` |
| T8 (verification) | — | `t008-green.txt` (format/analyze/suites/mutation record) |
