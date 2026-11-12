# Feature Specification: Signals Reactive Core Upgrades

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1725-signals-reactive-core`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "All those surgical updates to Zuraffa framework at once: lazy cached Computed, batched writes, identical-first equality, signal scope ownership, dispose reentrancy hardening, honest lifecycle doc contracts (from the oref/alien_signals code-level comparison)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Derived state costs nothing until read (Priority: P1)

As an app developer using Zuraffa signals, I can declare a derived value that
recomputes ONLY when one of its declared inputs actually changed AND something
reads it. Screens that are not visible never pay recompute cost, and a derived
value with zero readers propagates nothing at all.

**Why this priority**: Today `Signal.map`/`combine` are always-hot: the
transform runs on every parent change, even with zero downstream readers, and
`SlicePresenter.combinedState` eagerly initializes every slice. At app scale
this is continuous wasted work; laziness is the single biggest missing
primitive (proven pattern: alien_signals `Computed`).

**Independent Test**: Can be fully tested by creating a derived value from a
signal, changing the source twice without reading, and asserting the compute
callback ran zero times; then reading and asserting it ran exactly once.

**Acceptance Scenarios**:

1. **Given** a derived value declared from a source signal, **When** the source
   changes twice and the derived value is never read, **Then** the compute
   callback runs zero times
   **Type**: unit
2. **Given** a derived value with a cached read, **When** the source is set to
   a new value and the derived value is read, **Then** the compute callback ran
   exactly once for the new value
   **Type**: unit
3. **Given** a derived value that was already read, **When** it is read again
   without any dependency changing, **Then** the cached value is returned and
   the compute callback does not run again
   **Type**: unit
4. **Given** a derived value declared from two source signals, **When** only
   one source changes, **Then** the next read recomputes exactly once using
   the current values of both sources
   **Type**: unit

---

### User Story 2 - One batch, one notification (Priority: P2)

As an app developer, I can group several signal writes into one batch so that
each listener is notified exactly once at the end of the outermost batch, and
no listener ever observes intermediate states between the writes.

**Why this priority**: Zuraffa has no write coalescing today: every `set`
notifies immediately and synchronously, so a refresh touching N slices fires N
notification cascades and a listener of two slices can observe a state between
the two writes.

**Independent Test**: Can be fully tested by writing three signals inside a
batch with one listener on a combination of them, and asserting the listener
saw exactly one notification carrying all three final values.

**Acceptance Scenarios**:

1. **Given** a batch enclosing three signal writes, **When** the batch exits,
   **Then** each listener fired exactly once
   **Type**: unit
2. **Given** a batch in progress, **When** a signal is read inside the batch
   after a write, **Then** the read returns the newly written value (reads are
   never deferred)
   **Type**: unit
3. **Given** a callback inside a batch that throws, **When** the error
   propagates, **Then** the deferred notifications are still flushed (the
   boundary ends in a finally; there is no rollback)
   **Type**: unit
4. **Given** a nested batch inside another batch, **When** the inner batch
   exits, **Then** notifications stay deferred until the OUTERMOST batch exits
   **Type**: unit
5. **Given** the same signal written twice inside one batch, **When** the
   batch flushes, **Then** listeners see only the final value (per-signal
   coalescing, no duplicate notifications)
   **Type**: unit

---

### User Story 3 - Re-setting the same object never notifies (Priority: P3)

As an app developer working with Zuraffa's immutable entities, writing a value
that is the identical object (or equal by the configured equality) never
triggers notifications, and the identity check happens before any deep
equality work.

**Why this priority**: The default change gate is `==` alone, so every set pays
full field equality even when the same instance is re-assigned. Zorphy's
immutable entities make an identity fast-path always correct and nearly free.

**Independent Test**: Can be fully tested by re-assigning the same instance to
a signal with a listener attached and asserting zero notifications.

**Acceptance Scenarios**:

1. **Given** a signal holding an object, **When** the identical instance is
   assigned again, **Then** no listener fires
   **Type**: unit
2. **Given** a signal with a custom equality function, **When** a value the
   custom function considers equal is assigned, **Then** no listener fires
   (custom equality keeps working unchanged)
   **Type**: unit

---

### User Story 4 - A scope owns everything created inside it (Priority: P4)

As an app developer, I can run a scope boundary and have every signal created
inside it registered automatically; disposing the scope disposes them all, so
manual `registerSignal`-style bookkeeping becomes unnecessary.

**Why this priority**: Disposal today is manual (`ViewState.registerSignal`,
slice-level tracking). A missed dispose is a leak; an ownership primitive
removes the failure mode (proven pattern: effect scopes in alien_signals).

**Independent Test**: Can be fully tested by creating several signals inside a
scope, disposing the scope, and asserting every signal reports disposed and
its listeners were released.

**Acceptance Scenarios**:

1. **Given** signals created inside a scope's run boundary, **When** the scope
   is disposed, **Then** all of them are disposed and their listeners released
   **Type**: unit
2. **Given** a scope created inside another scope, **When** the outer scope is
   disposed, **Then** the inner scope and its signals are disposed too
   (ownership nests)
   **Type**: unit
3. **Given** a scope, **When** a signal is created OUTSIDE any scope run
   boundary, **Then** it is not owned by the scope (no global capture)
   **Type**: unit

---

### User Story 5 - Notifications survive hostile listeners (Priority: P5)

As an app developer, a listener that cancels itself or disposes the signal
mid-notification never receives a stale delivery afterwards, and disposing a
parent result releases derived children it produced.

**Why this priority**: Today `_notify` iterates a snapshot, so a listener can
keep receiving values for a signal that was disposed during the same
notification, and `SignalResult.flatMap` leaves its output orphaned when the
parent is disposed (leak).

**Independent Test**: Can be fully tested with two listeners where the first
disposes the signal during notification, asserting the second listener
receives nothing further and no state error escapes.

**Acceptance Scenarios**:

1. **Given** a notification with listeners A and B, **When** A disposes the
   signal during its callback, **Then** B receives nothing from that
   notification and the signal ends disposed without errors
   **Type**: unit
2. **Given** a notification with listeners A and B, **When** A cancels B's
   subscription during its callback, **Then** B receives nothing from that
   notification (cancellation takes effect immediately)
   **Type**: unit
3. **Given** a result derived through a flat map, **When** the parent result
   is disposed, **Then** the derived output is disposed as well (no orphan)
   **Type**: unit

---

### User Story 6 - The lifecycle rules are written down (Priority: P6)

As an app developer (human or AI agent) reading the signals API, I can rely on
documented contracts for subscribe-time eager delivery and listener-error
propagation, instead of discovering both by debugging.

**Why this priority**: `listen` delivers the current value synchronously at
subscribe time (a reentrancy hazard) and a throwing listener halts the
notification cascade and propagates to the setter; neither is documented
anywhere. Undocumented behavior is where agents and humans write wrong code.

**Independent Test**: Can be verified by reading the API documentation of the
listen entry point and the notification path, which must state both contracts
explicitly.

**Acceptance Scenarios**:

1. **Given** the signals API documentation, **When** a developer reads the
   listen entry point, **Then** the eager synchronous delivery of the current
   value at subscribe time is stated explicitly
   **Type**: acceptance
2. **Given** the signals API documentation, **When** a developer reads the
   notification contract, **Then** it states that a listener exception stops
   the remaining notifications and propagates to the caller that set the value
   **Type**: acceptance

---

### Edge Cases

- What happens when a derived value's dependency is disposed before first read?
  The read must throw the signal's disposed-state error, not crash the
  computed machinery.
- What happens when a batch callback schedules async work? The boundary is
  synchronous: it ends when the callback returns; work after `await` is
  outside the batch (documented, not transactional).
- What happens when a derived value is read inside its own compute callback?
  Recursion must fail fast (a clear state error), not hang or return stale
  cache.
- What happens when the same listener subscribes twice? Two independent
  registrations, two deliveries (identity dedup is NOT promised).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The framework MUST provide a lazy, cached derived value over
  explicitly declared source signals that recomputes only on the first read
  after an actual source change
            traces: Computed
- **FR-002**: The framework MUST provide a synchronous batching boundary that
  defers all listener notifications until the outermost boundary exits,
  coalescing repeated writes to the same signal to their final value
            traces: batch
- **FR-003**: The default change detection of a signal MUST check identity
  before structural equality while preserving custom equality functions
  unchanged
            traces: Signal
- **FR-004**: The framework MUST provide a scope that automatically owns and
  disposes every signal created inside its run boundary, nesting with parent
  scopes
            traces: SignalScope
- **FR-005**: The notification path MUST guarantee that a listener cancelled
  or a signal disposed during a notification receives no further values from
  that notification, and that disposing a parent reactive result disposes its
  derived flat-mapped output
            traces: Signal
- **FR-006**: The framework MUST document the subscribe-time eager delivery
  contract and the listener-error propagation contract on the public API
- **FR-007**: All changes MUST be backward-compatible: existing public
  signatures and behaviors of Signal, SignalResult, SignalSlice, and
  SlicePresenter remain unchanged, and their existing tests stay green
            traces: Signal

## Layer Contracts

**Function**:
- `Computed`: `Computed(List<ReadonlySignal<dynamic>> dependencies, T Function() compute) -> Computed<T>`
- `batch`: `batch(T Function() callback) -> T`
- `SignalScope`: `run(T Function() callback) -> T`
- `SignalScope`: `dispose() -> void`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| Computed<T> | `dependencies`, cached value, dirty flag | Lazy cached derived value; recomputes only when read after a dependency changed |
| SignalScope | owned signals, active-run state, parent link | Automatic ownership group; disposes everything created inside its boundary |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A derived value with an unread window performs exactly zero
  compute calls across any number of source writes, and exactly one per read
  following a change
- **SC-002**: N signal writes inside one batch produce exactly one listener
  notification per listener, carrying the final values
- **SC-003**: Re-assigning the identical instance produces zero notifications
- **SC-004**: A disposed scope disposes 100% of the signals created inside it
  and none created outside it
- **SC-005**: The pre-existing signals test suite passes unmodified
  (backward compatibility is measurable, not asserted)

## Assumptions

- Additions are non-breaking: no existing public signature of the signals
  stack changes (FR-007 guards this).
- No second reactive engine is introduced: a derived value takes an explicit
  dependency list; there is no automatic read-tracking, no custom scheduler,
  no graph engine (the "no second engine" discipline from the alien_signals
  comparison).
- The batching boundary is synchronous only; it does not cross `await` and
  provides no rollback.
- Eager delivery on subscribe (current behavior) is kept and documented, not
  changed; the same for listener-error propagation semantics — the goal is
  honest contracts, not new isolation policy.
