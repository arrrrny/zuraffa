# TDD Cycle Log: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Started**: 2026-11-11
**Test list**: [test-list.md](test-list.md) | **Profile**: Dart 3.13 stable, single-file `dart test` runs

Log format: one entry per behavior: `RED` (failing test proven) → `GREEN` (minimal implementation) → `REFACTOR` (if any) with evidence (command + result).

## Baseline (T004, FR-007)

| Suite | Result | Evidence |
| -- | -- | -- |
| test/core/signal_pipeline_test.dart | GREEN (36 tests, unmodified) | `dart test test/core/signal_pipeline_test.dart` → All tests passed! |
| test/state/signal_slice_test.dart | GREEN (7 tests, unmodified) | `dart test` → All tests passed! |
| test/state/slice_presenter_test.dart | GREEN (7 tests, unmodified) | `dart test` → All tests passed! |
| test/state/cache_observer_test.dart | GREEN (10 tests, unmodified) | `dart test` → All tests passed! |

Dart SDK 3.14.0 stable bootstrapped; `dart pub get --no-example` (repo-documented flow, pubspec.lock unchanged).

## Cycle log

### A. Computed — lazy cached derived value (US1, FR-001)

| Behavior | RED | GREEN | Notes |
| -- | -- | -- | -- |
| A1–A7b (8 tests) | RED: `Error: Undefined name 'Computed'` (loading failure of computed_test.dart) | GREEN: 8/8 passed | RED evidence: compile error on missing primitive; GREEN: `dart test test/core/signals/computed_test.dart` → All tests passed! |

Notes: one TEST-side fix mid-cycle (A5 self-reference needs a nullable local in Dart); no production refactor needed. Push-mode note: `_markDirty` recomputes only when listeners exist — subscribers are readers. FR-007 spot check after GREEN: `test/core/signal_pipeline_test.dart` still 36/36 unmodified.

### B. batch — synchronous notification deferral (US2, FR-002)

| Behavior | RED | GREEN | Notes |
| -- | -- | -- | -- |
| B1–B6 (6 tests) | RED: `Error: Method not found: 'batch'` (4 occurrences) | GREEN: 6/6 passed | GREEN: `dart test test/core/signals/batch_test.dart` → All tests passed! |

Regression after GREEN: `signal_pipeline_test.dart` 36/36, `computed_test.dart` 8/8 — both unmodified. Implementation: depth counter + `LinkedHashSet` of pending signals; flush in `finally`; per-signal coalescing for free because `_notify` reads `_value` at flush time.

### C. Signal — identity-first equality (US3, FR-003)

| Behavior | RED | GREEN | Notes |
| -- | -- | -- | -- |
| C1–C4 (5 tests) | RED: C1b `Expected: <1> Actual: <2>` (pathological `==` always false → identical write notified) | GREEN: 5/5 passed | GREEN: `dart test test/core/signals/equality_test.dart` → All tests passed! |

Notes: C1/C2/C4 already pass under `==`-only (correctly suppressed writes); the GATE ORDER is proven observable by C1b where `==` lies about identity. Fix: `_defaultEquals` → `identical(a, b) || a == b` (one line + dartdoc). Custom equals untouched (C3). Regression after GREEN: `signal_pipeline_test.dart` 36/36, `signal_slice_test.dart` 7/7 — unmodified.

### D. SignalScope — auto-ownership (US4, FR-004)

| Behavior | RED | GREEN | Notes |
| -- | -- | -- | -- |
| D1–D6 (6 tests) | RED: `Error: Method not found: 'SignalScope'` | GREEN: 6/6 passed | GREEN: `dart test test/core/signals/signal_scope_test.dart` → All tests passed! |

Notes: D6 added beyond the list (run restores previous active scope in finally — the boundary-composition guarantee). Construction-time parent link gives nesting; `Signal` constructor registers into the active scope only. Regression after GREEN: `signal_pipeline_test.dart` 36/36, `batch_test.dart` 6/6 — unmodified.

### E. Notification path — reentrancy hardening (US5, FR-005)

| Behavior | RED | GREEN | Notes |
| -- | -- | -- | -- |
| E1, E2, E3 (3 of 5 failing) | RED: E1 `Expected: <1> Actual: <2>` (B received stale delivery after mid-notify dispose); E2 `Expected: <1> Actual: <2>`; E3 `Expected: true Actual: <false>` (flatMap out orphaned) | GREEN: 5/5 passed | GREEN: `dart test test/core/signals/signal_reentrancy_test.dart` → All tests passed! |

Notes (honest): first GREEN attempt fixed E1/E3 but E2 still failed — `_listeners` was a `HashSet` with UNSPECIFIED iteration order, so "A cancels B mid-notification" could run B first, legitimately. REFACTOR: listeners became a FIFO `List` (subscription-order delivery, a documented contract upgrade, not a workaround). After refactor: all 5 green. flatMap fix: parent `_disposables` gains `out.dispose` (cascade), verified against E3b (output disposed while parent alive stops propagation).

### F. Backward compatibility (FR-007, T070)

`dart test test/state/ test/core/signals/ test/core/signal_pipeline_test.dart --concurrency=2` → **134/134 passed**, zero existing tests modified. Baseline suites (pipeline 36, slice 7, presenter 7, cache_observer 10) individually re-verified green after every cycle.
