import 'dart:collection';

/// A pure-Dart signal primitive for Zuraffa v8 with Expando + WeakReference owner bindings.
class ZfaSignal<T> implements ZfaReadonlySignal<T> {
  ZfaSignal(T initialValue, {Object? owner, bool Function(T a, T b)? equals})
      : _value = initialValue,
        _equals = equals ?? _defaultEquals,
        _listeners = [] {
    if (owner != null) {
      _bindOwner(owner, this);
    }
    _registerGlobal(this);
  }

  T _value;
  int _version = 0;
  int get version => _version;
  final bool Function(T a, T b) _equals;
  final List<_ZfaSignalListener<T>> _listeners;
  int _listenerEpoch = 0;
  bool _disposed = false;

  // Expando for weak ownership tracking
  static final Expando<List<ZfaSignal<dynamic>>> _ownerExpando = Expando<List<ZfaSignal<dynamic>>>();
  static final List<ZfaSignal<dynamic>> _allSignals = [];

  static void _bindOwner(Object owner, ZfaSignal<dynamic> signal) {
    final list = _ownerExpando[owner] ??= [];
    list.add(signal);
  }

  static void _registerGlobal(ZfaSignal<dynamic> signal) {
    _allSignals.add(signal);
  }

  /// Automatically dispose all signals owned by [owner] (via WeakReference / Expando).
  static void disposeOwner(Object owner) {
    final list = _ownerExpando[owner];
    if (list != null) {
      for (final signal in list) {
        signal.dispose();
      }
      _ownerExpando[owner] = null;
    }
  }

  @override
  T get value {
    _assertNotDisposed();
    return _value;
  }

  set value(T newValue) {
    _assertNotDisposed();
    if (_equals(_value, newValue)) return;
    _value = newValue;
    _version++;
    if (_batchDepth > 0) {
      _pendingSignals.add(this);
    } else {
      _notify();
    }
  }

  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  @override
  ZfaSignalSubscription listen(void Function(T value) callback) {
    _assertNotDisposed();
    final listener = _ZfaSignalListener<T>(callback);
    _listeners.add(listener);
    _listenerEpoch++;
    try {
      callback(_value);
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
    final derived = ZfaSignal<R>(transform(_value));
    if (derived.isDisposed) return derived;
    final sub = listen((v) {
      final next = transform(v);
      if (derived.isDisposed) return;
      derived.value = next;
    });
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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final hooks = _disposeHooks;
    _disposeHooks = null;
    _listeners.clear();
    _listenerEpoch++;
    hooks?.forEach((h) => h());
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('ZfaSignal has been disposed.');
  }

  void _notify() {
    if (_disposed) return;
    final snapshot = _listeners.toList(growable: false);
    final epoch = _listenerEpoch;
    for (final listener in snapshot) {
      if (_disposed) return;
      if (epoch != _listenerEpoch && !_listeners.contains(listener)) continue;
      listener.callback(_value);
    }
  }

  List<void Function()>? _disposeHooks;

  void Function() onDispose(void Function() hook) {
    if (_disposed) return () {};
    _disposeHooks ??= [];
    _disposeHooks!.add(hook);
    return () {
      _disposeHooks?.remove(hook);
    };
  }

  static bool _defaultEquals<T>(T a, T b) => identical(a, b) || a == b;
}

class ZfaSignalSubscription {
  ZfaSignalSubscription(this._cancel);
  final void Function() _cancel;
  void cancel() => _cancel();
}

class _ZfaSignalListener<T> {
  _ZfaSignalListener(this.callback);
  final void Function(T value) callback;

  @override
  bool operator ==(Object other) => identical(this, other);
  @override
  int get hashCode => identityHashCode(this);
}

abstract class ZfaReadonlySignal<T> {
  T get value;
  ZfaSignalSubscription listen(void Function(T value) callback);
  ZfaSignal<R> map<R>(R Function(T value) transform, {bool autoDispose = true});
}

// Batching support
int _batchDepth = 0;
final LinkedHashSet<ZfaSignal<dynamic>> _pendingSignals = LinkedHashSet();

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
    if (_pendingSignals.isNotEmpty) {
      _flushBatch();
    }
  }
}
