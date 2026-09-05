# Plan: 0966-typed-ledger-rows (extends 075-ui-coverage-ledger, issue #966)

## Context

The #963 coverage ledger (`lib/src/tdd/services/ui_ledger_builder.dart`) derives rows
with surface kinds `text | route | affordance` and proves them via green behaviors.
That schema is presence-only and therefore gameable (issue #966's all-9-literals-`Column`
demonstration). The finder-kind taxonomy (#964, `lib/src/plugins/tdd/services/finder_taxonomy.dart`)
already classifies scenario verbs into assertion classes
(`presence | absence | routeOutcome | enabledState | sequence`) in the widget lane —
the ledger never saw it.

## Approach

Add a **typed row schema** beside the surface ledger and make the gate + overlay
kind-aware:

1. `lib/src/tdd/services/typed_ledger_row.dart` (new) — the typed schema:
   - `LedgerRowKind` enum: `presence | absence | navigation | state | sequence` plus
     `golden` (advisory-only, per the recorded goldens decision).
   - `LedgerRowKind.fromScenarioVerb(String)` — plan-time kind assignment from scenario
     verbs (composes with #964's taxonomy; precedence sequence > navigation > absence >
     state > presence; golden scenarios yield advisory golden rows).
   - `DeclaredLedgerRow` (plan-time declaration: surface, kind, declared provers,
     kind-specific attributes) and `TypedLedgerRow` (derived row: recomputed state).
   - `TypedLedgerBuilder.derive/toMarkdown/toJson` — same read-time state recomputation
     discipline as #963 (green is the only proof).
   - `KindCoverage` + `TypedLedgerBuilder.kindCoverage` — per-kind traced/total counts.
   - `TypedCoverageVerdict` + `TypedCoverageGate.evaluate` — the #963 gate discipline
     extended: row gaps (unproven rows, #963 shape) **plus kind gaps** (a declared kind
     with zero traced rows is a gap naming the kind). Advisory (golden) rows are
     excluded from the verdict outcome and reported separately with their per-platform
     tolerance.
2. `lib/src/tdd/services/xray_ledger_binding.dart` (extend) — the overlay/deck render
   **kind coverage**: per screen, every declared kind with traced/total counts; untraced
   kinds highlight (never painted as proof).

Kind-specific semantics (carried on the row, asserted by the tracing behavior):

- absence: `notRenderedIn` — the state in which the surface must be hidden
  ("error banner hidden initially" → `notRenderedIn: initial`).
- sequence: `steps` — the interaction chain (`tap → loading → resolve → navigate`).
- state: `attribute` — the asserted widget attribute
  (`buttons disabled in flight` → `enabled = false @ in-flight`).
- golden: `platformTolerance` — per-platform pixel tolerance (advisory).

## Work affected

- `lib/src/tdd/services/typed_ledger_row.dart` (new)
- `lib/src/tdd/services/xray_ledger_binding.dart` (kind-coverage rendering)
- `lib/tdd/0966-typed-ledger-rows/` subjects + `test/tdd/0966-typed-ledger-rows/` tests
  (the repo's dogfooding harness, same shape as 075)
- `specs/0966-typed-ledger-rows/` artifacts (this directory)

## Deliberate decisions (recorded)

- **Goldens stay out of the merge gate.** Flaky economics on slow CI: pixel snapshots
  are advisory rows with per-platform tolerance; the verdict records them as advisory
  and they never block a landing. (Issue #966, recorded here as the deliberate decision.)
- **Kinds are assigned at plan time from scenario verbs**, never inferred post hoc —
  the gaming view cannot re-label a row to dodge a kind gap.
- **The typed gate composes with, and does not weaken, the #963 gate**: every row gap
  remains a gap; kind gaps are additive; advisory rows are the only exclusion.

## Verification

`dart analyze` clean · `tools/run_tests_chunked.sh` (no NEW failures) ·
`dart format .` zero-diff · `zfa tdd verify --feature 0966-typed-ledger-rows`
(real mutation audit → `tdd/verification.md`).
