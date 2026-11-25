import 'zfa_signal.dart';

/// A lazy, cached derived value over explicitly declared [ZfaReadonlySignal] dependencies.
class ZfaComputed<T> implements ZfaReadonlySignal<T>, ZfaPropagationNode {
  ZfaComputed(
    List<ZfaReadonlySignal<dynamic>> dependencies,
    T Function() compute,
  ) : _dependencies = List.of(dependencies),
      _compute = compute {
    for (final dep in _dependencies) {
      try {
        _subscriptions.add(dep.listen((_) => _markDirty()));
      } catch (e) {
        for (final sub in _subscriptions) {
          sub.cancel();
        }
        _subscriptions.clear();
        rethrow;
      }
    }
  }

  final List<ZfaReadonlySignal<dynamic>> _dependencies;
  final T Function() _compute;
  final List<ZfaSignalSubscription> _subscriptions = [];
  final List<_ZfaComputedListener<T>> _listeners = [];
  final List<void Function()> _disposeHooks = [];

  T? _value;
  bool _hasValue = false;
  bool _dirty = true;
  bool _computing = false;
  bool _disposed = false;
  int _listenerEpoch = 0;
  int _version = 0;
  final List<int> _depVersions = [];
  T? _lastDelivered;
  bool _hasDelivered = false;

  @override
  T get value {
    _assertNotDisposed();
    // `_dirty` alone is not enough inside a `batch`: the dependency callbacks
    // have not run yet, so the flag is still false. Validate captured versions
    // on every read so a read mid-batch recomputes from fresh dependencies.
    if (_dirty || !_hasValue || _isStale()) {
      _recompute();
    }
    return _value as T;
  }

  /// True when any dependency changed since the last compute. A dependency that
  /// is itself a [ZfaComputed] is validated recursively: its own version may
  /// still match while its cache is stale deeper in the graph.
  ///
  /// [seen] memoises nodes already visited in this pass so a shared dependency
  /// reached down two branches is validated once, not once per path.
  bool _isStale({Set<ZfaComputed<dynamic>>? seen}) {
    if (!_hasValue || _dependencies.isEmpty) return false;
    if (_depVersions.length != _dependencies.length) return true;
    final visited = seen ?? <ZfaComputed<dynamic>>{};
    if (!visited.add(this)) return false;
    for (var i = 0; i < _dependencies.length; i++) {
      final dep = _dependencies[i];
      final captured = _depVersions[i];
      if (dep is ZfaSignal) {
        if (dep.version != captured) return true;
      } else if (dep is ZfaComputed) {
        if (dep._version != captured) return true;
        if (dep._isStale(seen: visited)) return true;
      }
    }
    return false;
  }

  @override
  ZfaSignalSubscription listen(void Function(T value) callback) {
    _assertNotDisposed();
    final enteringPushMode = _listeners.isEmpty;
    final listener = _ZfaComputedListener<T>(callback);
    _listeners.add(listener);
    _listenerEpoch++;
    try {
      callback(value);
      if (enteringPushMode) {
        _lastDelivered = _value;
        _hasDelivered = true;
      }
    } catch (e) {
      _listeners.remove(listener);
      _listenerEpoch++;
      rethrow;
    }
    return ZfaSignalSubscription(() {
      _listeners.remove(listener);
      _listenerEpoch++;
    });
  }

  @override
  ZfaSignal<R> map<R>(
    R Function(T value) transform, {
    bool autoDispose = true,
  }) {
    final derived = ZfaSignal<R>(transform(value));
    final sub = listen((v) {
      final next = transform(v);
      if (derived.isDisposed) return;
      derived.value = next;
    });
    if (derived.isDisposed) {
      sub.cancel();
      return derived;
    }
    final removeParentHook = _onDispose(() {
      sub.cancel();
      if (autoDispose) derived.dispose();
    });
    derived.onDispose(() {
      sub.cancel();
      removeParentHook();
    });
    return derived;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final hooks = List<void Function()>.from(_disposeHooks);
    _disposeHooks.clear();
    _listeners.clear();
    _listenerEpoch++;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    zfaRunDisposeHooks(hooks);
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('ZfaComputed has been disposed.');
  }

  void _recompute() {
    if (_computing) {
      throw StateError(
        'ZfaComputed value was read inside its own compute callback.',
      );
    }
    _computing = true;
    try {
      _value = _compute();
      _hasValue = true;
      _dirty = false;
      _version++;
      _depVersions.clear();
      for (final dep in _dependencies) {
        if (dep is ZfaSignal) {
          _depVersions.add(dep.version);
        } else if (dep is ZfaComputed) {
          _depVersions.add(dep._version);
        } else {
          _depVersions.add(0);
        }
      }
    } finally {
      _computing = false;
    }
  }

  void _markDirty() {
    if (_disposed) return;
    _dirty = true;
    // Lazy mode: nobody is reading, so invalidation is enough. In push mode
    // schedule delivery — the propagation scope flushes only after every
    // sibling dependency has been invalidated (diamond coherence).
    if (_listeners.isNotEmpty) {
      zfaScheduleComputed(this);
    }
  }

  @override
  void deliverPendingZfa() {
    if (_disposed || _listeners.isEmpty) return;
    _dirty = true; // a failed recompute must leave the cache invalid for retry
    final hadValue = _hasDelivered;
    final previous = _lastDelivered;
    _recompute();
    final changed =
        !hadValue || !(identical(previous, _value) || previous == _value);
    if (changed) {
      _lastDelivered = _value;
      _hasDelivered = true;
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    if (_disposed) return;
    final snapshot = List.of(_listeners);
    final epoch = _listenerEpoch;
    Object? firstError;
    StackTrace? firstStack;
    for (final listener in snapshot) {
      if (_disposed) break;
      if (epoch != _listenerEpoch && !_listeners.contains(listener)) continue;
      try {
        listener.callback(_value as T);
      } catch (e, st) {
        // Finish the remaining listeners before reporting the first failure.
        firstError ??= e;
        firstStack ??= st;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  void Function() _onDispose(void Function() hook) {
    _disposeHooks.add(hook);
    return () {
      _disposeHooks.remove(hook);
    };
  }
}

class _ZfaComputedListener<T> {
  _ZfaComputedListener(this.callback);
  final void Function(T value) callback;

  @override
  bool operator ==(Object other) => identical(this, other);
  @override
  int get hashCode => identityHashCode(this);
}
