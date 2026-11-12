# API Contracts: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Date**: 2026-11-11

Contracts traced from spec.md Layer Contracts. All new public API is
additive (FR-007): no existing signature changes.

## `Computed` (lib/src/core/signals/computed.dart)

```dart
Computed<T>(List<ReadonlySignal<dynamic>> dependencies, T Function() compute)
  -> Computed<T>
```

- `Computed<T> implements ReadonlySignal<T>`: exposes `value` and `listen`.
- Read contract: returns cache unless `_dirty`; recomputes at most once per
  read-after-change; zero compute calls while unread with no listeners.
- Recursion: reading `.value` inside `compute` throws `StateError`.
- Dispose: cancels dependency subscriptions, releases listeners, idempotent.
- Error contract: a disposed dependency read propagates its `StateError`
  (no swallowing).

## `batch` (lib/src/core/signals/signal.dart)

```dart
T batch<T>(T Function() callback) -> T
```

- Top-level function (exported via the existing signal.dart export).
- Writes inside the boundary update `_value` immediately (reads see them);
  notifications defer to the outermost boundary exit.
- Per-signal coalescing: each affected signal notifies exactly once, with
  its final value.
- Flush runs in `finally`: a throwing callback still flushes; there is no
  rollback.
- Sync-only: the boundary ends when `callback` returns; work scheduled after
  an `await` is outside the batch (documented on the function).

## `SignalScope` (lib/src/core/signals/signal.dart)

```dart
SignalScope.run<T>(T Function() callback) -> T
SignalScope.dispose() -> void
```

- `run`: makes this scope the active creation boundary for the duration of
  `callback` (restored in `finally`); every `Signal` constructed inside is
  auto-owned.
- Nesting: a `SignalScope` constructed while another scope is running
  becomes its child; parent disposal disposes children and their signals.
- Signals constructed outside any `run` boundary are never captured.
- `dispose`: disposes children first, then owned signals; idempotent.

## `Signal` (changed behavior, unchanged signature)

```dart
Signal(T initialValue, {bool Function(T a, T b)? equals})
set value(T newValue)
SignalSubscription listen(void Function(T value) callback)
```

- Default equality gate becomes `identical(a, b) || a == b` (custom `equals`
  fully preserved).
- `listen` documented: delivers the current value synchronously at subscribe
  time.
- Notification path documented: a listener exception stops remaining
  deliveries and propagates to the setter; listeners cancelled or signals
  disposed during a notification receive no further values from it.

## `SignalResult.flatMap` (changed behavior, unchanged signature)

- Parent disposal now cascades to the derived output: `out` is disposed when
  the parent `SignalResult` is disposed (no orphan).
