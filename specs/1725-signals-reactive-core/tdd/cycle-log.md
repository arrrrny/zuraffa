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
