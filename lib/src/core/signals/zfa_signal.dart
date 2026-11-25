import 'dart:collection';

/// Internal coordination hook implemented by computed nodes so a single signal
/// write can mark every affected computed dirty before any of them recomputes
/// or delivers — the precondition for glitch-free diamond updates.
abstract class ZfaPropagationNode {
  void deliverPendingZfa();
}

// ── Propagation coordination ────────────────────────────────────────────────
//
// A signal write opens a scope, notifies ALL of its listeners (each dependent
// computed merely marks itself dirty and schedules itself), then closes the
// scope. Only the closing edge drains the scheduled nodes. That ordering is
// what prevents a diamond from delivering an intermediate value: both `b` and
// `c` are invalidated before `d` is allowed to recompute.
int _propagationDepth = 0;
final LinkedHashSet<ZfaPropagationNode> _pendingComputed =
    LinkedHashSet<ZfaPropagationNode>();
bool _flushingComputed = false;

void zfaEnterPropagation() => _propagationDepth++;

void zfaExitPropagation() {
  if (_propagationDepth > 0) _propagationDepth--;
  if (_propagationDepth == 0) _flushComputed();
}

void zfaScheduleComputed(ZfaPropagationNode node) {
  _pendingComputed.add(node);
  if (_propagationDepth == 0) _flushComputed();
}

void _flushComputed() {
  if (_flushingComputed || _pendingComputed.isEmpty) return;
  _flushingComputed = true;
  Object? firstError;
  StackTrace? firstStack;
  try {
    while (_pendingComputed.isNotEmpty) {
      final batch = _pendingComputed.toList(growable: false);
      _pendingComputed.clear();
      for (final node in batch) {
        try {
          node.deliverPendingZfa();
        } catch (e, st) {
          firstError ??= e;
          firstStack ??= st;
        }
      }
    }
  } finally {
    _flushingComputed = false;
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}

/// Runs every hook even when one throws, then rethrows the FIRST failure with
/// its original stack trace. A throwing hook must never strand the cleanup
/// behind it (the node is already marked disposed and its hooks cleared).
void zfaRunDisposeHooks(Iterable<void Function()> hooks) {
  Object? firstError;
  StackTrace? firstStack;
  for (final hook in hooks) {
    try {
      hook();
    } catch (e, st) {
      firstError ??= e;
      firstStack ??= st;
    }
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}

/// A pure-Dart signal primitive for Zuraffa v8 with Expando + WeakReference owner bindings.
class ZfaSignal<T> implements ZfaReadonlySignal<T> {
  ZfaSignal(T initialValue, {Object? owner, bool Function(T a, T b)? equals})
    : _value = initialValue,
      _equals = equals ?? _defaultEquals,
      _listeners = [] {
    if (owner != null) {
      _bindOwner(owner, this);
    }
  }

  T _value;
  int _version = 0;
  int get version => _version;
  final bool Function(T a, T b) _equals;
  final List<_ZfaSignalListener<T>> _listeners;
  int _listenerEpoch = 0;
  bool _disposed = false;

  // Expando for weak ownership tracking. There is deliberately NO strong
  // global registry: a signal owned by an expando key must become collectible
  // as soon as its owner and its callers drop it.
  static final Expando<List<ZfaSignal<dynamic>>> _ownerExpando =
      Expando<List<ZfaSignal<dynamic>>>();

  static void _bindOwner(Object owner, ZfaSignal<dynamic> signal) {
    final list = _ownerExpando[owner] ??= [];
    list.add(signal);
  }

  /// Automatically dispose all signals owned by [owner] (via WeakReference / Expando).
  static void disposeOwner(Object owner) {
    final list = _ownerExpando[owner];
    if (list == null) return;
    _ownerExpando[owner] = null;
    final signals = List<ZfaSignal<dynamic>>.from(list);
    zfaRunDisposeHooks(signals.map((s) => s.dispose));
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
  ZfaSignal<R> map<R>(
    R Function(T value) transform, {
    bool autoDispose = true,
  }) {
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
    // Keep the remover so a disposed mapping does not leave a capturing hook
    // in this (possibly long-lived) source's hook list forever.
    void Function()? removeParentHook;
    if (autoDispose) {
      removeParentHook = onDispose(() => derived.dispose());
    }
    derived.onDispose(() {
      sub.cancel();
      removeParentHook?.call();
    });
    return derived;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final hooks = _disposeHooks;
    _disposeHooks = null;
    _listeners.clear();
    _listenerEpoch++;
    zfaRunDisposeHooks(hooks ?? const <void Function()>[]);
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('ZfaSignal has been disposed.');
  }

  void _notify() {
    if (_disposed) return;
    Object? firstError;
    StackTrace? firstStack;
    // Keep the whole listener pass in one propagation scope: every dependent
    // computed is invalidated before the first of them is allowed to deliver.
    zfaEnterPropagation();
    try {
      final snapshot = _listeners.toList(growable: false);
      final epoch = _listenerEpoch;
      for (final listener in snapshot) {
        if (_disposed) break;
        if (epoch != _listenerEpoch && !_listeners.contains(listener)) continue;
        try {
          listener.callback(_value);
        } catch (e, st) {
          // A throwing callback must not stop later listeners — in particular
          // the computed-subscription listeners that invalidate dependents.
          firstError ??= e;
          firstStack ??= st;
        }
      }
    } finally {
      zfaExitPropagation();
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
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
  Object? firstError;
  StackTrace? firstStack;
  try {
    // One scope for every pending signal: all writes in the batch settle
    // before any computed node is allowed to recompute and deliver.
    zfaEnterPropagation();
    try {
      while (_pendingSignals.isNotEmpty) {
        final pending = _pendingSignals.toList(growable: false);
        _pendingSignals.clear();
        for (final signal in pending) {
          if (signal._disposed) continue;
          try {
            signal._notify();
          } catch (e, st) {
            firstError ??= e;
            firstStack ??= st;
          }
        }
      }
    } finally {
      zfaExitPropagation();
    }
  } finally {
    _batchDepth--;
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}
