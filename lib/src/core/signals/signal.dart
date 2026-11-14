import 'dart:collection';

/// A zero-cost reactive signal primitive for zuraffa.
///
/// [Signal] provides O(1) reads and fine-grained subscriptions.
/// Unlike [ValueNotifier], it does not notify on every [set] — only when
/// the value actually changes (identity, then `==`, or custom [equals]).
///
/// Disposal is explicit via [dispose]. Listeners are automatically
/// cleaned up when the signal is disposed, and a listener that disposes
/// this signal (or cancels another listener's subscription) during a
/// notification stops the remaining deliveries of that notification.
///
/// Related: [batch] for write coalescing, [SignalScope] for automatic
/// ownership, [Computed] for lazy derived values.
class Signal<T> implements ReadonlySignal<T> {
  Signal(T initialValue, {bool Function(T a, T b)? equals})
    : _value = initialValue,
      _equals = equals ?? _defaultEquals,
      _listeners = [] {
    SignalScope._registerSignal(this);
  }

  T _value;
  int _version =
      0; // incremented on every accepted write for Computed freshness
  /// Version of the last accepted write. Read by `Computed` for freshness checks.
  int get version => _version;
  final bool Function(T a, T b) _equals;
  final List<_SignalListener<T>> _listeners;
  int _listenerEpoch = 0; // incremented on listener mutations (O(n²) guard)
  bool _disposed = false;

  // ── Public API ──

  /// Current value. O(1) read — no subscription overhead.
  @override
  T get value {
    _assertNotDisposed();
    return _value;
  }

  /// Replace the current value. Notifies listeners only if [equals]
  /// returns `false`.
  ///
  /// Inside a [batch] boundary the write takes effect immediately (reads see
  /// the new value) but the listener notification is deferred to the exit of
  /// the outermost batch, coalesced per-signal to the final value.
  set value(T newValue) {
    _assertNotDisposed();
    if (_equals(_value, newValue)) return;
    _value = newValue;
    _version++; // bump version for Computed freshness tracking
    if (_batchDepth > 0) {
      _pendingSignals.add(this);
    } else {
      _notify();
    }
  }

  /// Functional update: `signal.update((v) => v + 1)`.
  /// Notifies only when the result differs.
  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  /// Subscribe to value changes. Returns an unsubscribable [SignalSubscription].
  ///
  /// ## Contract (read this before wiring listeners)
  ///
  /// - **Eager delivery**: the current value is delivered SYNCHRONOUSLY at
  ///   subscribe time, before this method returns. Code that both listens and
  ///   reacts by writing the same signal must guard against reentrancy.
  /// - **Delivery order**: listeners are notified in subscription order
  ///   (FIFO).
  /// - **Cancellation**: a subscription cancelled during a notification
  ///   receives no further values from that notification; if the signal is
  ///   disposed during a notification, the remaining listeners are skipped.
  /// - **Error propagation**: a listener that throws stops the notification
  ///   cascade at that listener and the exception propagates to the caller
  ///   that set the value (or to the exit of the enclosing [batch]). There is
  ///   no isolation between listeners — keep them non-throwing. A listener
  ///   that throws during the EAGER delivery leaves no registration behind:
  ///   the subscribe fails atomically, the exception reaches the caller of
  ///   [listen], and this signal keeps no listener (the caller never received
  ///   a subscription they could have used to cancel it).
  ///
  /// Subscribing the same callback twice creates two independent
  /// registrations and two deliveries.
  @override
  SignalSubscription listen(void Function(T value) callback) {
    _assertNotDisposed();
    final listener = _SignalListener<T>(callback);
    _listeners.add(listener);
    _listenerEpoch++; // mutation guard for O(n²) avoidance
    // Eager delivery of current value (cold-start behaviour).
    try {
      callback(_value);
    } catch (e) {
      // The delivery runs the caller's code, and it can throw (a derived
      // combinator's transform that disposes its scope and then touches a
      // signal the scope owned, for one). The registration was added before
      // the delivery and the subscription below never reaches the caller, so
      // the throw must remove it here: a leaked listener re-enters this
      // callback on every later write of this signal. Same cleanup
      // `Computed.listen` performs for its own eager delivery.
      _listeners.remove(listener);
      _listenerEpoch++; // mutation guard for O(n²) avoidance
      rethrow;
    }
    return SignalSubscription(() {
      _listeners.remove(listener);
      _listenerEpoch++; // mutation guard for O(n²) avoidance
    });
  }

  /// Transform this signal into a derived [Signal] of type [R].
  /// The derived signal automatically disposes when the parent disposes
  /// if [autoDispose] is true (default).
  @override
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) {
    final derived = Signal<R>(transform(_value));
    // A scope disposed inside its own `run` releases the derived signal at
    // construction (SignalScope._registerSignal). Subscribing now would
    // eagerly write to that disposed signal: the write throws before `listen`
    // returns the subscription, so the cleanup could never be installed and
    // this source would keep a listener that throws on every later write.
    if (derived.isDisposed) return derived;
    final sub = listen((v) {
      // The transform is the user's code and it runs before the write: a
      // transform that disposes the scope owning `derived` disposes `derived`
      // too, so the write has to be re-checked after it, not only on entry.
      final next = transform(v);
      if (derived.isDisposed) return;
      derived.value = next;
    });
    // The same disposal can happen during the eager delivery `listen` just
    // ran. Cancelling the registration is what closes the leak: without it the
    // source keeps a listener that throws on every later write, and the caller
    // never receives the subscription it would need to cancel.
    if (derived.isDisposed) {
      sub.cancel();
      return derived;
    }
    derived.onDispose(() => sub.cancel());
    if (autoDispose) {
      onDispose(() => derived.dispose());
    }
    return derived;
  }

  /// Combine two signals into one.
  static Signal<R> combine<T1, T2, R>(
    Signal<T1> s1,
    Signal<T2> s2,
    R Function(T1 a, T2 b) combiner,
  ) {
    final derived = Signal<R>(combiner(s1._value, s2._value));
    // See [map]: a derived signal disposed during its own construction must be
    // returned before any source is subscribed.
    if (derived.isDisposed) return derived;
    void sync() {
      // The combiner is the user's code and it runs before the write: one that
      // disposes the scope owning `derived` leaves `derived` dead, so the
      // write has to be re-checked after it — see [map].
      final next = combiner(s1._value, s2._value);
      if (derived.isDisposed) return;
      derived.value = next;
    }

    final sub1 = s1.listen((_) => sync());
    SignalSubscription sub2;
    try {
      sub2 = s2.listen((_) => sync());
    } catch (e) {
      // s2.listen cleans its own registration (atomic subscribe); the
      // subscription taken on s1 above is still live and unreachable —
      // cancel it before propagating. Same cleanup the [Computed]
      // constructor performs when a later dependency fails to subscribe.
      sub1.cancel();
      rethrow;
    }
    // A combiner that disposed its own scope during either eager delivery
    // above leaves `derived` dead and both sources listening: cancel both.
    if (derived.isDisposed) {
      sub1.cancel();
      sub2.cancel();
      return derived;
    }
    derived.onDispose(() {
      sub1.cancel();
      sub2.cancel();
    });
    return derived;
  }

  /// Dispose the signal and release all listeners.
  ///
  /// Hooks are saved before clearing to prevent concurrent modification
  /// issues if a dispose hook triggers additional signal mutations.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final hooks = _disposeHooks;
    _disposeHooks = null;
    _listeners.clear();
    _listenerEpoch++; // mutation guard for O(n²) avoidance
    hooks?.forEach((h) => h());
  }

  bool get isDisposed => _disposed;

  // ── Internal ──

  void _assertNotDisposed() {
    if (_disposed) throw StateError('Signal has been disposed.');
  }

  void _notify() {
    if (_disposed) return;
    // Iterate over a copy to allow mutation during iteration, but guard each
    // delivery: a listener cancelled mid-notification (or a signal disposed
    // mid-notification) must not receive stale deliveries.
    final snapshot = _listeners.toList(growable: false);
    final epoch = _listenerEpoch;
    for (final listener in snapshot) {
      if (_disposed) return; // hostile dispose mid-notification: stop remaining
      // Only check contains() if the list was mutated (O(n²) → O(n) fast path)
      if (epoch != _listenerEpoch && !_listeners.contains(listener)) continue;
      listener.callback(_value);
    }
  }

  List<void Function()>? _disposeHooks;

  /// Register [hook] to run when this signal is disposed.
  ///
  /// Exposed for derived combinators that live in another library (for
  /// example [Computed.map]), which must release their own subscriptions when
  /// the derived signal goes away. Hooks run in registration order; registering
  /// after disposal is ignored — the signal is already released.
  ///
  /// Returns a function that removes the hook again, so a caller that no longer
  /// needs it (because the resource it releases is gone) does not keep it — and
  /// whatever the hook captures — alive for the lifetime of this signal.
  void Function() onDispose(void Function() hook) {
    if (_disposed) return () {};
    _disposeHooks ??= [];
    _disposeHooks!.add(hook);
    return () {
      _disposeHooks?.remove(hook);
    };
  }

  /// Default change gate: identity first (near-free), then structural
  /// equality. Re-assigning the identical instance never notifies even when
  /// `==` would report a change.
  static bool _defaultEquals<T>(T a, T b) => identical(a, b) || a == b;
}

/// Lightweight subscription handle. Call [cancel] to unsubscribe.
class SignalSubscription {
  SignalSubscription(this._cancel);
  final void Function() _cancel;
  void cancel() => _cancel();
}

/// Internal listener wrapper. Identity-based equality so cancellation
/// and the mid-notification membership check are precise.
class _SignalListener<T> {
  _SignalListener(this.callback);
  final void Function(T value) callback;

  @override
  bool operator ==(Object other) => identical(this, other);
  @override
  int get hashCode => identityHashCode(this);
}

/// A read-only view of a [Signal].
abstract class ReadonlySignal<T> {
  T get value;
  SignalSubscription listen(void Function(T value) callback);
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true});
}

extension ReadonlySignalExtension<T> on Signal<T> {
  // Signal already satisfies ReadonlySignal<T> via direct interface conformance.
}

// ── Batching ──
//
// Synchronous notification-deferral boundary. Writes inside a batch update
// the value immediately (reads are never deferred); only the listener
// notifications defer until the outermost batch exits.

int _batchDepth = 0;
final LinkedHashSet<Signal<dynamic>> _pendingSignals = LinkedHashSet();

/// Run [callback] as a synchronous batching boundary for signal writes.
///
/// Every signal written inside the boundary notifies its listeners exactly
/// once — at the exit of the OUTERMOST [batch], carrying the final value
/// (repeated writes to the same signal coalesce). Reads inside the boundary
/// always see freshly written values.
///
/// ## Contract
///
/// - **Synchronous only**: the boundary ends when [callback] returns. Work
///   scheduled after an `await` inside the callback runs OUTSIDE the batch.
/// - **No rollback**: if [callback] throws, the deferred notifications are
///   still flushed (the flush runs in a `finally`), and the error propagates
///   to the caller.
/// - Nested batches defer to the outermost boundary.
///
/// Example:
///
/// ```dart
/// batch(() {
///   a.value = 1;
///   b.value = 2; // listeners see exactly one update: (1, 2)
/// });
/// ```
T batch<T>(T Function() callback) {
  _batchDepth++;
  try {
    return callback();
  } finally {
    _batchDepth--;
    if (_batchDepth == 0) {
      _flushBatch();
    }
  }
}

void _flushBatch() {
  if (_pendingSignals.isEmpty) return;
  // Keep batch depth elevated during flush to defer listener writes
  _batchDepth++;
  try {
    final pending = _pendingSignals.toList(growable: false);
    _pendingSignals.clear();
    for (final signal in pending) {
      if (!signal._disposed && !_pendingSignals.contains(signal)) {
        signal._notify();
      }
    }
  } finally {
    _batchDepth--;
    // Recursively flush any signals written by listeners during this flush
    if (_pendingSignals.isNotEmpty) {
      _flushBatch();
    }
  }
}

// ── Scope ownership ──
//
// A SignalScope automatically owns every Signal constructed inside its
// [SignalScope.run] boundary, removing manual register/dispose bookkeeping.

/// An automatic ownership group for signals.
///
/// Every [Signal] constructed while a scope's [run] boundary is active is
/// owned by that scope; [dispose] disposes them all (releasing their
/// listeners). Scopes nest: a scope CONSTRUCTED inside another scope's
/// `run` becomes its child and is disposed with it.
///
/// ## Contract
///
/// - Ownership is creation-scoped, not global: signals created outside any
///   `run` boundary are never captured.
/// - [run] restores the previously active scope when it exits (a `finally`),
///   so boundaries compose and interleave safely.
/// - [run] on a disposed scope throws a [StateError] without running the
///   callback, and a signal constructed after its active scope was disposed
///   is disposed immediately: a disposed scope can never release either.
/// - [dispose] is idempotent and disposes children before owned signals.
///
/// Example:
///
/// ```dart
/// final scope = SignalScope();
/// scope.run(() {
///   final a = Signal(1); // auto-owned
/// });
/// scope.dispose(); // a is disposed, listeners released
/// ```
class SignalScope {
  SignalScope() {
    final parent = _activeScope;
    if (parent != null) {
      parent._children.add(this);
    }
  }

  static SignalScope? _activeScope;
  static void _registerSignal(Signal<dynamic> signal) {
    final scope = _activeScope;
    if (scope == null) return;
    if (scope._disposed) {
      // The scope was disposed inside its own `run` callback (or before the
      // signal was constructed): it will never release this signal, so
      // release it here instead of leaving a live signal nobody owns.
      signal.dispose();
      return;
    }
    scope._owned.add(signal);
  }

  final List<SignalScope> _children = [];
  final List<Signal<dynamic>> _owned = [];
  bool _disposed = false;

  /// Run [callback] with this scope as the active signal-creation boundary.
  /// Signals constructed during the callback are owned by this scope.
  ///
  /// **Synchronous only**: the boundary ends when [callback] returns. Work
  /// scheduled after an `await` inside the callback runs OUTSIDE this scope,
  /// so signals created there may not be owned by this scope (possibly owned
  /// by nothing).
  ///
  /// Throws a [StateError] when this scope is already disposed: a disposed
  /// scope can never release what it owns, so running one would silently
  /// produce signals nobody owns.
  T run<T>(T Function() callback) {
    if (_disposed) {
      throw StateError('SignalScope has been disposed.');
    }
    final previous = _activeScope;
    _activeScope = this;
    try {
      return callback();
    } finally {
      _activeScope = previous;
    }
  }

  /// Dispose this scope: child scopes first, then every owned signal.
  /// Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final children = List.of(_children);
    _children.clear();
    for (final child in children) {
      child.dispose();
    }
    final owned = List.of(_owned);
    _owned.clear();
    for (final signal in owned) {
      signal.dispose();
    }
  }

  bool get isDisposed => _disposed;
}
