# Tasks: Signals Reactive Core Upgrades

**Input**: Design documents from `/specs/1725-signals-reactive-core/`

**Tests**: Mandatory — this feature runs the TDD extension (red-green-refactor). Every behavior task is test-first.

**Organization**: Grouped by user story (US1..US6 from spec.md).

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Branch `1725-signals-reactive-core` created (before_specify hook, FEATURE_NUM 1725)
- [x] T002 Spec + requirements checklist written and committed (9b235cc)
- [x] T003 Plan, research, data-model, contracts, quickstart written
- [x] T004 Bootstrap Dart SDK in verification rig + `dart pub get` (pub.zuzu.dev token); confirm baseline: existing `test/core/signal_pipeline_test.dart` + `test/state/signal_slice_test.dart` green BEFORE any source edit (FR-007 evidence)

## Phase 2: Foundational (Blocking Prerequisites)

*None — the feature adds to an existing, compiling package. T004 baseline is the only gate.*

---

## Phase 3: US1 — Lazy derived state (Priority: P1) 🎯 MVP

**Goal**: `Computed<T>` recomputes only on first read after an actual dependency change.
**Independent Test**: change source twice without reading → compute ran zero times; read → exactly once.

### Tests first (must FAIL before implementation)

- [x] T010 [P] [US1] `test/core/signals/computed_test.dart`: lazy window (A1), recompute-once-after-change (A2), cache-hit (A3), two-deps-one-change (A4), read-in-own-compute throws (A5), disposed-dep read propagates StateError (A6), Computed satisfies ReadonlySignal + listen eager delivery (A7)

### Implementation

- [x] T011 [US1] Create `lib/src/core/signals/computed.dart`: `Computed<T>` with dirty-flag cache, explicit dependency list, push-only-when-listened, recursion guard, dispose
- [x] T012 [US1] Export `computed.dart` in `lib/zuraffa.dart`

**Checkpoint**: US1 green; lazy semantics proven by counters.

---

## Phase 4: US2 — batch() (Priority: P2)

**Goal**: outermost boundary defers + coalesces notifications; reads immediate.
**Independent Test**: three writes + double-write in one batch → one notification, final values.

### Tests first

- [x] T020 [P] [US2] `test/core/signals/batch_test.dart`: exactly-one-notification (B1), reads-see-writes-inside (B2), throwing-callback-still-flushes (B3), nested-batch-outermost-flush (B4), per-signal-coalescing (B5), no-batch-change-behavior-unchanged (B6)

### Implementation

- [x] T021 [US2] `signal.dart`: `_batchDepth` + `_pendingSignals` state, `set value` deferral branch, top-level `batch()` with finally-flush; sync-boundary dartdoc

**Checkpoint**: US2 green; notification storms collapsed to one cascade.

---

## Phase 5: US3 — Identity-first equality (Priority: P3)

**Goal**: default gate `identical(a, b) || a == b`; custom equals untouched.
**Independent Test**: same instance re-assigned → zero notifications.

### Tests first

- [x] T030 [P] [US3] `test/core/signals/equality_test.dart`: identical-reread zero-notify (C1), equal-by-== zero-notify (C2), custom-equals preserved (C3), different value notifies (C4)

### Implementation

- [x] T031 [US3] `signal.dart`: `_defaultEquals` becomes identity-first; dartdoc states the gate order

**Checkpoint**: US3 green; fast-path wins measurable (zero notify on identity).

---

## Phase 6: US4 — SignalScope (Priority: P4)

**Goal**: scope auto-owns signals created inside `run`; nesting; dispose-all.
**Independent Test**: create signals inside scope, dispose scope → all disposed, outside-created untouched.

### Tests first

- [x] T040 [P] [US4] `test/core/signals/signal_scope_test.dart`: dispose-all-owned (D1), nesting (D2), outside-not-captured (D3), listeners-released (D4), scope dispose idempotent (D5)

### Implementation

- [x] T041 [US4] `signal.dart`: `SignalScope` class (static `_active`, `run`, `dispose`, child registration), constructor hook in `Signal`

**Checkpoint**: US4 green; manual registration bookkeeping now optional.

---

## Phase 7: US5 — Dispose-reentrancy hardening (Priority: P5)

**Goal**: mid-notify cancel/dispose stops remaining deliveries; flatMap orphan fixed.
**Independent Test**: listener A disposes signal mid-notification → B receives nothing, no error escapes.

### Tests first

- [x] T050 [P] [US5] `test/core/signals/signal_reentrancy_test.dart`: mid-notify-dispose halts (E1), mid-notify-cancel takes effect immediately (E2), parent-SignalResult-dispose cascades to flatMap out (E3), double-dispose safe (E4)

### Implementation

- [x] T051 [US5] `signal.dart`: hardened `_notify()` (disposed guard + contains guard)
- [x] T052 [US5] `signal_result.dart`: `flatMap` registers `out.dispose()` on parent `_disposables`

**Checkpoint**: US5 green; hostile listeners can no longer produce stale deliveries or orphans.

---

## Phase 8: US6 — Honest doc contracts (Priority: P6)

- [x] T060 [US6] dartdoc on `Signal.listen` (eager subscribe-time delivery), `set value`/notification path (listener error halts cascade, propagates to setter), `Computed` (lazy contract), `batch` (sync boundary, no rollback), `SignalScope` (ownership semantics)

---

## Phase 9: Cross-cutting & verification

- [x] T070 Run full signals-affected suites: 4 new files + `signal_pipeline_test.dart` + `signal_slice_test.dart` + `slice_presenter_test.dart` + `cache_observer_test.dart` (FR-007 unmodified-green evidence)
- [x] T071 `dart analyze` clean on changed files
- [x] T072 Write `tdd/verification.md` audit (scenarios ↔ evidence table); re-cycle on any FAIL (cap 3)
- [x] T073 Run quickstart.md examples as a smoke (the snippets are the API surface)
- [x] T074 Commit chain, push, byte-verify, open PR citing #2071

## Dependencies & Execution Order

- T004 blocks all implementation phases (baseline evidence first).
- US1..US5 phases are independent of each other EXCEPT they all edit `signal.dart` (US2, US3, US4, US5) — execute sequentially in the listed order to keep every red→green cycle attributable. US1 (computed.dart) is the only parallelizable file.
- US6 (docs) last: it documents contracts implemented in US1..US5.
- T070/T072 gate T074.

## Notes

- Every behavior task is red-green-refactor: prove red on the new test file before touching `lib/`.
- Single-file `dart test` runs only (1 GB cgroup; no parallel suite runs in-sandbox).
- Commit after each green cycle (branch-as-checkpoint, pushed).
