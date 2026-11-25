import 'zfa_signal.dart';

/// A lazy, cached derived value over explicitly declared [ZfaReadonlySignal] dependencies.
class ZfaComputed<T> implements ZfaReadonlySignal<T> {
  ZfaComputed(List<ZfaReadonlySignal<dynamic>> dependencies, T Function() compute)
    : _dependencies = List.of(dependencies),
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
    if (_dirty || !_hasValue) {
      _recompute();
    }
    return _value as T;
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
  ZfaSignal<R> map<R>(R Function(T value) transform, {bool autoDispose = true}) {
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
    final hooks = List.of(_disposeHooks);
    _disposeHooks.clear();
    _listeners.clear();
    _listenerEpoch++;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final hook in hooks) {
      hook();
    }
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('ZfaComputed has been disposed.');
  }

  void _recompute() {
    if (_computing) {
      throw StateError('ZfaComputed value was read inside its own compute callback.');
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
    if (_listeners.isEmpty) {
      _dirty = true;
      return;
    }
    _dirty = true;
    final hadValue = _hasDelivered;
    final previous = _lastDelivered;
    _recompute();
    final changed = !hadValue || !(identical(previous, _value) || previous == _value);
    if (changed) {
      _lastDelivered = _value;
      _hasDelivered = true;
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    final snapshot = List.of(_listeners);
    final epoch = _listenerEpoch;
    for (final listener in snapshot) {
      if (_disposed) return;
      if (epoch != _listenerEpoch && !_listeners.contains(listener)) continue;
      listener.callback(_value as T);
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
