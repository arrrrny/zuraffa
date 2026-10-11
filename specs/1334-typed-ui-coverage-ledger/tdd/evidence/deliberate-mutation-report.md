# Deliberate Mutation Report (spec 1334, issue #1143)

Production code under audit: `typed_ledger_row.dart` + `xray_ledger_binding.dart`.
Per-mutant scope: the 1334 + 0966 ledger subject suites (18 tests).
A mutant is KILLED when any pin fails; SURVIVED means a coverage hole.

| # | mutant (the #1143 seam it breaks) | result | killed by |
| - | ---------------------------------- | ------ | --------- |
| M1 | `zeroTraced` gains `&& total > 0` — 0/0 kinds stop being gaps (the presence-only screen reads clean — AC-2 broken) | KILLED | T2 (all-five-kinds report), T3 (gate), T7 (polarity pins) |
| M2 | `fromLedgerJson` hard-codes `legacy: false` — kindless 075 ledgers get the tightened gate (AC-6 broken: existing projects go red) | KILLED | T6 (legacy mode) |
| M3 | screen status drops the row-gap condition — a screen with red rows reads `fully-traced` (kinds traced, rows not) | KILLED | T3 (row-gap gate), T7 (status polarity pin) |
| M4 | `fromScenario` drops the plan-time golden advisory flag — golden rows become gate surface (AC-5 broken: goldens could block) | KILLED | T1 (golden advisory), T5 (composed advisory) |
| M5 | `evaluateScreens` counts row gaps only — the gaming presence-only screen PASSES the per-screen gate (the whole point of #1143) | KILLED | T3 (gate fails gaming ledger), T8 (failure-line count) |
| M6 | `renderScreen` drops the HIGHLIGHT marker — zero-traced kinds render like clean ones, painted as proof (AC-3 broken) | KILLED | T4 (per-kind overlay rendering) |
| M7 | `fromLedgerJson` stops recognizing the 0966 `golden` label — golden-only artifacts read legacy, golden rows lose the forced advisory | KILLED | T6 (golden-only 0966 artifact reads typed + advisory forced) |
| M8 | the vocabulary gains a sixth kind value — the five-kind contract (AC-1) is violated | KILLED | T1 (enumeration pin), T7 (order pin) |
| M9 | `kindCoverageAllKinds` skips undeclared kinds (back to the 0966 declared-only view) — the presence-only screen loses its 0/0 gaps | KILLED | T2, T3, T7, T8 |
| M10 | the feature-wide verdict drops the kind-gap arm (`unproven == 0` alone) — EQUIVALENT BY INVARIANT: `unproven == 0` implies every declared kind traced, so the arm is unreachable | SURVIVED (equivalent — the arm is defensive documentation of AC-6, unreachable when unproven == 0) | — |

Final state: both files restored from backup; the 1334 + 0966 suites
re-run green after restore (see `t00*-green.txt` + `0966-regression-green.txt`).

Post-restore sanity run: GREEN (all 18 tests pass on the restored code).
