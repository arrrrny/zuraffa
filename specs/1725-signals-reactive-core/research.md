# Research: Signals Reactive Core Upgrades

**Feature**: 1725-signals-reactive-core | **Date**: 2026-11-11
**Method**: direct source comparison (no .md references, per fleet directive)

## Compared sources

- **medz/oref** (github.com/medz/oref): Dart port of alien_signals; push-based
  signals with lazy `Computed`, `batch`, effect scopes.
- **alien_signals** (the upstream oref mirrors): `computedSetup` with a
  `_dirty` flag, `startBatch/endBatch` depth counter, effect-scope ownership.
- **Zuraffa real code**: `lib/src/core/signals/signal.dart` (154 lines),
  `signal_result.dart` (206 lines) — read in full, line-verified.

## Findings (code-level, each mapped to a spec story)

1. **Lazy derived values** (oref `Computed`): alien_signals marks a computed
   dirty on input change and recomputes on next READ; zero subscribers =
   zero work. Zuraffa's `Signal.map`/`Signal.combine` are always-hot: the
   transform runs on every parent change regardless of readers, and
   `map` even computes once at derivation time. → Lazy `Computed` with
   explicit dependency list (oref's auto-tracking is a second engine —
   rejected per the no-second-engine discipline).
2. **Batching** (oref `batch`): depth counter, defers notifications to the
   outermost exit. Zuraffa has nothing: N sets = N cascades, listeners of
   multiple slices observe intermediate states. → Top-level `batch()` with
   finally-flush and per-signal coalescing (a deferred signal notifies once
   with its final `_value`, because `_notify` reads `_value` at flush time —
   no per-signal queue needed, a LinkedHashSet of pending signals suffices).
3. **Identity-first equality**: alien_signals checks `identical` first.
   Zuraffa's `_defaultEquals` is `a == b` — full structural compare even on
   same-instance writes. → `identical(a, b) || a == b`; custom `equals`
   untouched.
4. **Scope ownership** (alien_signals effect scopes): oref's `SignalScope`
   auto-registers signals created inside `run`. Zuraffa disposal is manual
   (`ViewState.registerSignal`, slice tracking) — a missed call is a leak.
   → `SignalScope.run` + static active-scope registration from the `Signal`
   constructor; nesting via construction-time parent link.
5. **Reentrancy**: Zuraffa `_notify` iterates a snapshot, so a listener
   cancelled or a signal disposed mid-notification still receives the pending
   delivery; `SignalResult.flatMap` registers cleanup only on the OUTPUT
   (`out._disposables`) — when the PARENT is disposed, `out` stays alive
   forever as a semantic orphan (listeners never released, loading stuck).
   → epoch/contains guard in `_notify`; parent `_disposables` gains the
   `out.dispose()` cascade.
6. **Honest contracts**: `Signal.listen` delivers the current value
   synchronously at subscribe time (reentrancy hazard, undocumented);
   `nextValue` already works around it. A throwing listener halts the
   cascade and propagates to the setter (undocumented). → Document both, on
   the public API, not in .md files.

## Risks

- **`SignalScope` in `signal.dart`** needs the constructor registration hook;
  kept same-library to respect Dart privacy (no public bridge).
- **Computed with listeners** is push (recompute-on-change to feed
  subscribers); pure laziness applies to the unread window. This is the
  alien_signals compromise and is stated in the spec contract.
- **Batch + eager-delivery interplay**: a listener attached INSIDE a batch
   still gets its synchronous subscribe-time delivery (reads are never
   deferred); only change notifications defer. Documented in quickstart.
