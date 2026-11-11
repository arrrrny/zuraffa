# Test List: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Generated**: 2026-11-11 (legacy single-file test list; no Lanes section in spec)
**Profile**: Dart 3.13 stable, `dart test <file> --plain-name "<name>"`, single-file runs (1 GB cgroup)

## Behaviors

### A. Computed — lazy cached derived value (US1, FR-001)
Source: `lib/src/core/signals/computed.dart` · Test file: `test/core/signals/computed_test.dart`

- A1: `computed: zero compute calls while source changes and derived is never read`
- A2: `computed: exactly one recompute on first read after a change`
- A3: `computed: repeated reads without dependency change return cache (no recompute)`
- A4: `computed: two dependencies, one change, recompute uses current values of both`
- A5: `computed: reading value inside its own compute throws StateError`
- A6: `computed: disposed dependency read propagates StateError, no swallow`
- A7: `computed: implements ReadonlySignal; listen delivers current value eagerly; dispose cancels dep subscriptions`

### B. batch — synchronous notification deferral (US2, FR-002)
Source: `lib/src/core/signals/signal.dart` · Test file: `test/core/signals/batch_test.dart`

- B1: `batch: three writes produce exactly one notification per listener`
- B2: `batch: reads inside the boundary see freshly written values`
- B3: `batch: throwing callback still flushes deferred notifications (finally, no rollback)`
- B4: `batch: nested batches defer until the outermost boundary exits`
- B5: `batch: same signal written twice notifies once with the final value`
- B6: `batch: writes outside any batch notify immediately (baseline unchanged)`

### C. Signal — identity-first equality (US3, FR-003)
Source: `lib/src/core/signals/signal.dart` · Test file: `test/core/signals/equality_test.dart`

- C1: `equality: re-assigning the identical instance never notifies`
- C2: `equality: equal-by-== assignment never notifies`
- C3: `equality: custom equals function is preserved unchanged`
- C4: `equality: a different value still notifies`

### D. SignalScope — auto-ownership (US4, FR-004)
Source: `lib/src/core/signals/signal.dart` · Test file: `test/core/signals/signal_scope_test.dart`

- D1: `scope: dispose disposes every signal created inside run`
- D2: `scope: nested scope is disposed with its parent`
- D3: `scope: signals created outside any run boundary are not captured`
- D4: `scope: disposal releases owned signals' listeners`
- D5: `scope: dispose is idempotent`

### E. Notification path — reentrancy hardening (US5, FR-005)
Source: `lib/src/core/signals/signal.dart`, `lib/src/core/signals/signal_result.dart` · Test file: `test/core/signals/signal_reentrancy_test.dart`

- E1: `reentrancy: signal disposed by listener A mid-notification stops B's delivery, no error escapes`
- E2: `reentrancy: listener cancelled by A mid-notification receives nothing from that notification`
- E3: `reentrancy: disposing parent SignalResult disposes its flatMap-derived output (no orphan)`
- E4: `reentrancy: double dispose of a signal is safe`

### F. Backward compatibility (US-all, FR-007)
No new test file: the gate is the EXISTING suites running green UNMODIFIED before and after.

- F1: `test/core/signal_pipeline_test.dart` green unmodified
- F2: `test/state/signal_slice_test.dart` green unmodified
- F3: `test/state/slice_presenter_test.dart` green unmodified
- F4: `test/state/cache_observer_test.dart` green unmodified
