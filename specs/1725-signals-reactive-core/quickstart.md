# Quickstart: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Date**: 2026-11-11

Four new primitives, one behavior fix, honest docs. All additive: existing
`Signal`/`SignalResult` code compiles and behaves exactly as before.

## Lazy derived values: `Computed`

```dart
final price = Signal(100);
final taxRate = Signal(0.2);

// Explicit dependencies, lazy + cached: compute runs ONLY on first read
// after a dependency actually changed.
final total = Computed<num>([price, taxRate], () => price.value * (1 + taxRate.value));

price.value = 250;          // no compute yet — nothing read total
print(total.value);         // 300.0 — exactly one compute call
print(total.value);         // 300.0 — cache, zero compute calls
```

`Computed` satisfies `ReadonlySignal`, so it composes with the existing API
(`listen`, `map`). Reading `.value` inside its own `compute` throws.

## Coalescing writes: `batch`

```dart
final a = Signal(0);
final b = Signal(0);
var builds = 0;
Signal.combine(a, b, (x, y) => (x, y)).listen((_) => builds++);
builds = 0;  // reset after eager delivery

batch(() {
  a.value = 1;
  b.value = 2;   // reads inside the batch see 1 and 2 already
  a.value = 3;   // same signal twice — coalesced
});
// builds == 1, carrying (3, 2). One cascade per batch, never intermediate states.
```

The boundary is synchronous: it ends when the callback returns. Work after
`await` is outside the batch. A throwing callback still flushes (no rollback).

## Identity-first equality

```dart
final user = Signal(const User(name: 'ada'));
user.listen((_) => print('changed'));

user.value = sameInstance;  // zero notifications — identical fast-path
user.value = const User(name: 'ada'); // zero notifications — == gate
user.value = const User(name: 'bob'); // one notification
```

## Ownership: `SignalScope`

```dart
final scope = SignalScope();
scope.run(() {
  final a = Signal(1);   // auto-owned by the scope
  final b = Signal(2);   // auto-owned
});
scope.dispose();          // a and b are disposed, listeners released
```

Nested: a scope created inside another scope's `run` is disposed with its
parent. Signals created outside any `run` boundary are never captured.

## Hostile listeners are safe

```dart
final s = Signal(0);
SignalSubscription? sub2;
final sub = s.listen((v) {
  if (v == 1) sub2?.cancel();   // cancels B mid-notification
});
sub2 = s.listen((v) {
  if (v == 1) fail('B must not receive this');
});
s.value = 1;                  // sub2 was cancelled before its delivery
```

Disposing a signal (or a parent `SignalResult` that `flatMap` derived) inside
a listener stops the remaining deliveries of that notification; a disposed
parent `SignalResult` now disposes its flat-mapped output (no orphan).

## Subscribe-time delivery (now documented, unchanged)

`listen` delivers the current value synchronously at subscribe time; a
listener that throws stops the notification cascade and propagates to the
caller that set the value. Both contracts are on the API dartdoc — the
behavior is the same as before the upgrade.
