import 'dart:collection';

/// A zero-cost reactive signal primitive for zuraffa.
///
/// [Signal] provides O(1) reads and fine-grained subscriptions.
/// Unlike [ValueNotifier], it does not notify on every [set] — only when
/// the value actually changes (by [==] or custom [equals]).
///
/// Disposal is explicit via [dispose]. Listeners are automatically
/// cleaned up when the signal is disposed.
class Signal<T> implements ReadonlySignal<T> {
  Signal(T initialValue, {bool Function(T a, T b)? equals})
    : _value = initialValue,
      _equals = equals ?? _defaultEquals,
      _listeners = HashSet<_SignalListener<T>>.identity();

  T _value;
  final bool Function(T a, T b) _equals;
  final HashSet<_SignalListener<T>> _listeners;
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
  set value(T newValue) {
    _assertNotDisposed();
    if (_equals(_value, newValue)) return;
    _value = newValue;
    _notify();
  }

  /// Functional update: `signal.update((v) => v + 1)`.
  /// Notifies only when the result differs.
  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  /// Subscribe to value changes. Returns an unsubscribable [SignalSubscription].
  @override
  SignalSubscription listen(void Function(T value) callback) {
    _assertNotDisposed();
    final listener = _SignalListener<T>(callback);
    _listeners.add(listener);
    // Eager delivery of current value (cold-start behaviour).
    callback(_value);
    return SignalSubscription(() => _listeners.remove(listener));
  }

  /// Transform this signal into a derived [Signal] of type [R].
  /// The derived signal automatically disposes when the parent disposes
  /// if [autoDispose] is true (default).
  @override
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) {
    final derived = Signal<R>(transform(_value));
    final sub = listen((v) => derived.value = transform(v));
    derived._onDispose(() => sub.cancel());
    if (autoDispose) {
      _onDispose(() => derived.dispose());
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
    void sync() => derived.value = combiner(s1._value, s2._value);
    final sub1 = s1.listen((_) => sync());
    final sub2 = s2.listen((_) => sync());
    derived._onDispose(() {
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
    hooks?.forEach((h) => h());
  }

  bool get isDisposed => _disposed;

  // ── Internal ──

  void _assertNotDisposed() {
    if (_disposed) throw StateError('Signal has been disposed.');
  }

  void _notify() {
    // Iterate over a copy to allow mutation during iteration.
    for (final listener in _listeners.toList(growable: false)) {
      listener.callback(_value);
    }
  }

  List<void Function()>? _disposeHooks;

  void _onDispose(void Function() hook) {
    _disposeHooks ??= [];
    _disposeHooks!.add(hook);
  }

  static bool _defaultEquals<T>(T a, T b) => a == b;
}

/// Lightweight subscription handle. Call [cancel] to unsubscribe.
class SignalSubscription {
  SignalSubscription(this._cancel);
  final void Function() _cancel;
  void cancel() => _cancel();
}

/// Internal listener wrapper. Identity-based equality so [HashSet]
/// deduplication works correctly.
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
