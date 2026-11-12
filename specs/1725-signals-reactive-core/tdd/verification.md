# TDD Verification: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Verified**: 2026-11-11
**Test list**: [test-list.md](test-list.md) | **Cycle log**: [cycle-log.md](cycle-log.md)
**Verdict**: PASS (all behaviors implemented with red-green evidence; FR-007 intact)

## Scenario coverage audit (spec ↔ evidence)

| Spec scenario (story) | Behavior | Test | Result |
| -- | -- | -- | -- |
| US1.1 zero compute while unread | A1 | computed_test.dart A1 | GREEN |
| US1.2 one recompute per read-after-change | A2 | computed_test.dart A2 | GREEN |
| US1.3 cache hit on unchanged read | A3 | computed_test.dart A3 | GREEN |
| US1.4 two deps, one change | A4 | computed_test.dart A4 | GREEN |
| Edge: read inside own compute | A5 | computed_test.dart A5 | GREEN |
| Edge: disposed dependency | A6 | computed_test.dart A6 | GREEN |
| US1 derived API usability | A7/A7b | computed_test.dart A7, A7b | GREEN |
| US2.1 one notification per batch | B1 | batch_test.dart B1 | GREEN |
| US2.2 reads immediate inside batch | B2 | batch_test.dart B2 | GREEN |
| US2.3 throwing callback still flushes | B3 | batch_test.dart B3 | GREEN |
| US2.4 outermost boundary | B4 | batch_test.dart B4 | GREEN |
| US2.5 per-signal coalescing | B5 | batch_test.dart B5 | GREEN |
| US2 baseline (no batch) unchanged | B6 | batch_test.dart B6 | GREEN |
| US3.1 identical never notifies | C1 (+C1b gate order) | equality_test.dart C1, C1b | GREEN |
| US3.2 custom equals preserved | C3 | equality_test.dart C3 | GREEN |
| US3 equal-by-== / different value | C2, C4 | equality_test.dart C2, C4 | GREEN |
| US4.1 dispose-all-owned | D1 | signal_scope_test.dart D1 | GREEN |
| US4.2 nesting | D2 | signal_scope_test.dart D2 | GREEN |
| US4.3 outside not captured | D3 | signal_scope_test.dart D3 | GREEN |
| US4 listeners released + edge | D4–D6 | signal_scope_test.dart D4, D5, D6 | GREEN |
| US5.1 mid-notify dispose halts | E1 | signal_reentrancy_test.dart E1 | GREEN |
| US5.2 mid-notify cancel immediate | E2 | signal_reentrancy_test.dart E2 | GREEN |
| US5.3 flatMap orphan fixed | E3 (+E3b reverse case) | signal_reentrancy_test.dart E3, E3b | GREEN |
| US5 double dispose edge | E4 | signal_reentrancy_test.dart E4 | GREEN |
| US6.1/6.2 doc contracts | — | dartdoc on `Signal.listen`/class/set-value + `Computed`/`batch`/`SignalScope` | DONE (T060) |

## FR audit

- **FR-001** lazy cached Computed: A1–A7b. PASS.
- **FR-002** batch deferral + coalescing: B1–B6. PASS.
- **FR-003** identity-first equality, custom preserved: C1–C4 + C1b. PASS.
- **FR-004** scope ownership + nesting: D1–D6. PASS.
- **FR-005** reentrancy + flatMap cascade: E1–E4. PASS.
- **FR-006** honest doc contracts: listen (eager delivery, FIFO, cancellation, error propagation), notify path, batch (sync-only, no rollback), scope, computed. PASS.
- **FR-007** backward compatibility: baseline suites captured BEFORE any edit (pipeline 36, slice 7, presenter 7, cache_observer 10), re-run unmodified after every cycle; final combined run `test/state/ + test/core/signals/ + pipeline` → **134/134 passed**, zero modifications to pre-existing tests. All new API is additive (`Computed`, `batch`, `SignalScope`); no existing public signature changed. PASS.

## Deviations (honest)

1. **FIFO delivery order (REFACTOR during E cycle)**: `_listeners` changed from identity-HashSet (unspecified iteration order) to a FIFO List. This makes mid-notification cancellation deterministic and is a documented contract upgrade; it is behavior-visible only where code relied on unspecified order (no fleet test did).
2. **Test-side fixes mid-cycle**: A5 (Dart self-reference in closure), E1 (test design corrected before RED was trusted), C1b added because C1/C2 pass under `==`-only — only C1b proves the gate ORDER observably.
3. **A7b, C1b, D6, E3b** added beyond the planned list to close honest gaps (push-skip on unchanged value, gate order, boundary restore, reverse-cascade). All in test-list scope of their groups.
4. `dart pub get --no-example` per repo-documented flow (example/ requires Flutter SDK); pubspec.lock unchanged.

## Success criteria check

- SC-001 zero compute while unread ✔ (A1) · exactly-one per read-after-change ✔ (A2)
- SC-002 N writes → one notification ✔ (B1, B5)
- SC-003 identical write → zero notifications ✔ (C1, C1b)
- SC-004 disposed scope → 100% owned disposed, none outside ✔ (D1, D3)
- SC-005 pre-existing suite green unmodified ✔ (134/134, baseline re-verified)

**Verdict: PASS** — no re-cycle needed. 1 pass used of the 3-pass cap.
