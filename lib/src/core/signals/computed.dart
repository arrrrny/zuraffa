import 'signal.dart';

/// A lazy, cached derived value over explicitly declared [ReadonlySignal]
/// dependencies.
///
/// Unlike [Signal.map] / [Signal.combine], which are always-hot (the transform
/// runs on every source change regardless of readers), a [Computed]
/// recomputes only on the FIRST read after a dependency actually changed:
///
/// - No listeners and no read: a dependency change only marks this computed
///   dirty — [compute] never runs. Derived state that nobody reads costs
///   nothing.
/// - [value] returns the cache until a dependency marks it dirty.
/// - With active [listen] subscribers the computed switches to push mode:
///   a dependency change recomputes and notifies immediately (subscribers
///   are readers).
///
/// ## Contract
///
/// - Dependencies are EXPLICIT: there is no automatic read tracking.
/// - Reading [value] inside [compute] (directly or transitively) throws a
///   [StateError] — recursion fails fast instead of hanging.
/// - A disposed dependency read propagates its [StateError]; nothing is
///   swallowed.
/// - [listen] delivers the current value synchronously at subscribe time
///   (same eager-delivery contract as [Signal.listen]).
/// - Notifications are gated by change detection: a dependency change that
///   leaves the computed value equal (identity, then `==`) notifies nobody.
///
/// Dispose via [dispose] cancels all dependency subscriptions and releases
/// listeners; it is idempotent.
class Computed<T> implements ReadonlySignal<T> {
  /// Create a lazy derived value over [dependencies].
  ///
  /// [compute] reads the dependency values it needs; it is called at most
  /// once per read-after-actual-change (or once per change while listeners
  /// are attached).
  Computed(List<ReadonlySignal<dynamic>> dependencies, T Function() compute)
    : _dependencies = List.of(dependencies),
      _compute = compute {
    for (final dep in _dependencies) {
      _subscriptions.add(dep.listen((_) => _markDirty()));
    }
  }

  final List<ReadonlySignal<dynamic>> _dependencies;
  final T Function() _compute;
  final List<SignalSubscription> _subscriptions = [];
  final List<void Function(T value)> _listeners = [];
  final List<void Function()> _disposeHooks = [];

  T? _value;
  bool _hasValue = false;
  bool _dirty = true;
  bool _computing = false;
  bool _disposed = false;

  /// Current derived value. O(1) — returns the cache unless a dependency
  /// changed since the last compute.
  @override
  T get value {
    _assertNotDisposed();
    if (_dirty || !_hasValue) {
      _recompute();
    }
    return _value as T;
  }

  /// Subscribe to derived value changes. Returns an unsubscribable
  /// [SignalSubscription]. The current value is delivered synchronously at
  /// subscribe time; while at least one subscriber is attached, dependency
  /// changes recompute and push immediately.
  @override
  SignalSubscription listen(void Function(T value) callback) {
    _assertNotDisposed();
    _listeners.add(callback);
    // Eager delivery of current value (same cold-start contract as Signal).
    callback(value);
    return SignalSubscription(() => _listeners.remove(callback));
  }

  /// Transform this computed into a derived [Signal] of type [R].
  ///
  /// The derived signal disposes together with this computed when
  /// [autoDispose] is true (default).
  @override
  Signal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) {
    final derived = Signal<R>(transform(value));
    final sub = listen((v) {
      if (!derived.isDisposed) derived.value = transform(v);
    });
    _onDispose(() {
      sub.cancel();
      if (autoDispose) derived.dispose();
    });
    return derived;
  }

  /// Dispose this computed: cancel all dependency subscriptions, release
  /// listeners, and run dispose hooks. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final hooks = List.of(_disposeHooks);
    _disposeHooks.clear();
    _listeners.clear();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final hook in hooks) {
      hook();
    }
  }

  bool get isDisposed => _disposed;

  // ── Internal ──

  void _assertNotDisposed() {
    if (_disposed) throw StateError('Computed has been disposed.');
  }

  void _recompute() {
    if (_computing) {
      throw StateError(
        'Computed value was read inside its own compute callback.',
      );
    }
    _computing = true;
    try {
      _value = _compute();
      _hasValue = true;
      _dirty = false;
    } finally {
      _computing = false;
    }
  }

  void _markDirty() {
    if (_disposed) return;
    if (_listeners.isEmpty) {
      // Lazy mode: nobody is reading — just invalidate.
      _dirty = true;
      return;
    }
    // Push mode: subscribers are readers — recompute now, notify on change.
    final hadValue = _hasValue;
    final previous = _value;
    _recompute();
    final changed =
        !hadValue || !(identical(previous, _value) || previous == _value);
    if (changed) {
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      if (_disposed) return;
      if (!_listeners.contains(listener)) continue;
      listener(_value as T);
    }
  }

  void _onDispose(void Function() hook) {
    _disposeHooks.add(hook);
  }
}
