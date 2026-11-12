import 'dart:async';

import '../failure.dart';
import 'signal.dart';
import '../result.dart';

/// A reactive wrapper around [Result<T, AppFailure>] backed by a [Signal].
///
/// [SignalResult] is the v6 replacement for raw `Stream<Result<T, AppFailure>>` in
/// [ZuraffaUseCase] return types. It provides:
///
/// - **O(1) reads**: `value` is a direct signal read, no stream overhead.
/// - **Zero-allocation snapshots**: previous result is cached until changed.
/// - **Fine-grained subscriptions**: listen to result changes without buffering.
/// - **Async-to-sync bridge**: `await` the next emission via [nextValue].
///
/// ## Lifecycle
///
/// [SignalResult] owns its internal [Signal]. When disposed, the signal is
/// disposed and all listeners are released.
class SignalResult<T> {
  SignalResult._(this._signal);

  /// Create a [SignalResult] from an initial [Result].
  factory SignalResult.initial(Result<T, AppFailure> result) =>
      SignalResult._(Signal<Result<T, AppFailure>>(result));

  /// Create a [SignalResult] from an initial success value.
  factory SignalResult.success(T value) => SignalResult._(
    Signal<Result<T, AppFailure>>(Success<T, AppFailure>(value)),
  );

  /// Create a [SignalResult] from an initial failure.
  factory SignalResult.failure(AppFailure error) => SignalResult._(
    Signal<Result<T, AppFailure>>(Failure<T, AppFailure>(error)),
  );

  /// Create a [SignalResult] from a [Future].
  ///
  /// The signal starts as [loading] (optional) and transitions to the
  /// resolved result when the future completes.
  static SignalResult<T> fromFuture<T>(
    Future<T> future, {
    bool emitLoading = true,
  }) {
    final sr = SignalResult<T>.initial(
      emitLoading
          ? LoadingResult<T, AppFailure>.loading()
          : LoadingResult<T, AppFailure>.idle(),
    );
    future.then(
      (v) {
        sr._signal.value = Success<T, AppFailure>(v);
      },
      onError: (e, st) {
        sr._signal.value = Failure<T, AppFailure>(AppFailure.from(e, st));
      },
    );
    return sr;
  }

  final Signal<Result<T, AppFailure>> _signal;

  // ── Read API ──

  /// Current result value. O(1) — direct signal read.
  Result<T, AppFailure> get value => _signal.value;

  /// Current data if [Success], otherwise `null`.
  T? get data => _signal.value.getOrNull();

  /// Current error if [Failure], otherwise `null`.
  AppFailure? get error => _signal.value.getFailureOrNull();

  /// Whether the current state is actively loading (not idle).
  bool get isLoading {
    final v = _signal.value;
    return v is LoadingResult<T, AppFailure> && !v.isIdle;
  }

  /// Whether the current state is a success.
  bool get isSuccess => _signal.value.isSuccess;

  /// Whether the current state is a failure.
  bool get isFailure => _signal.value.isFailure;

  // ── Write API (used by UseCase implementations) ──

  /// Publish a new [Result]. Notifies listeners only if the result changes.
  void emit(Result<T, AppFailure> result) => _signal.value = result;

  /// Publish a success value.
  void emitSuccess(T value) => _signal.value = Success<T, AppFailure>(value);

  /// Publish a failure.
  void emitFailure(AppFailure error) =>
      _signal.value = Failure<T, AppFailure>(error);

  /// Publish a loading state.
  void emitLoading() => _signal.value = LoadingResult<T, AppFailure>.loading();

  /// Functional update over the current result.
  void update(
    Result<T, AppFailure> Function(Result<T, AppFailure> current) updater,
  ) => _signal.update(updater);

  /// Update only the success data, preserving failure/loading states.
  ///
  /// If the current result is a [Success], applies [updater] to the data
  /// and emits the new success value. If the current result is a [Failure]
  /// or [LoadingResult], this is a no-op.
  void updateData(T Function(T currentData) updater) {
    final current = value;
    if (current is Success<T, AppFailure>) {
      emitSuccess(updater(current.value));
    }
  }

  // ── Subscription API ──

  /// Listen to result changes. Callback receives the new result immediately.
  SignalSubscription listen(
    void Function(Result<T, AppFailure> result) callback,
  ) => _signal.listen(callback);

  /// Listen only to success values.
  SignalSubscription onSuccess(void Function(T value) callback) => listen((r) {
    if (r is Success<T, AppFailure>) callback(r.value);
  });

  /// Listen only to failures.
  SignalSubscription onFailure(void Function(AppFailure error) callback) =>
      listen((r) {
        if (r is Failure<T, AppFailure>) callback(r.error);
      });

  /// Listen only to the next non-loading result (success or failure).
  Future<Result<T, AppFailure>> get nextValue async {
    final completer = Completer<Result<T, AppFailure>>();
    SignalSubscription? sub;
    var done = false;
    void handle(Result<T, AppFailure> r) {
      if (done) return;
      if (r is! LoadingResult<T, AppFailure>) {
        done = true;
        sub?.cancel();
        completer.complete(r);
      }
    }

    sub = listen(handle);
    // Eager delivery may have completed the future before `sub` was assigned.
    if (done) sub.cancel();
    return completer.future;
  }

  // ── Transformation ──

  /// Transform the success value, preserving failure/loading states.
  SignalResult<R> map<R>(R Function(T value) transform) {
    final mapped = SignalResult<R>._(
      _signal.map((r) => r.map(transform), autoDispose: false),
    );
    // Parent disposal cascades to the mapped result (as in flatMap). The child
    // is tracked as an object — not as its `dispose` tear-off — so disposing
    // the child releases this reference immediately (no retention).
    _adopt(mapped);
    return mapped;
  }

  /// Flat-map: chain another async operation on success.
  /// The previous inner subscription is cancelled before binding a new one.
  SignalResult<R> flatMap<R>(SignalResult<R> Function(T value) transform) {
    final out = SignalResult<R>.initial(LoadingResult<R, AppFailure>.idle());
    SignalSubscription? innerSub;

    final parentSub = listen((r) {
      if (r is Success<T, AppFailure>) {
        innerSub?.cancel();
        final newSub = transform(r.value).listen((nr) => out.emit(nr));
        // Check if out was disposed during eager delivery
        if (out.isDisposed) {
          newSub.cancel();
        } else {
          innerSub = newSub;
        }
      } else if (r is Failure<T, AppFailure>) {
        innerSub?.cancel();
        out.emitFailure(r.error);
      }
    });

    // Cancel both subscriptions when the output SIGNAL goes away — from
    // SignalResult.dispose() or from a SignalScope that owns it. Registering on
    // the signal is what makes the scope case work: a scope disposes the
    // signal directly, never this wrapper.
    out._signal.onDispose(() {
      parentSub.cancel();
      innerSub?.cancel();
      // The signal is gone, so the wrapper is dead too: dispose it here as
      // well, otherwise the parent keeps this output (and its own children)
      // retained until the parent itself is disposed.
      out.dispose();
    });
    // Parent disposal cascades to the derived output: without this, `out`
    // would outlive its parent as an orphan (listeners never released,
    // loading states stuck forever). Tracked as an object so a caller that
    // disposes `out` releases this reference immediately.
    if (isDisposed) {
      out.dispose();
    } else {
      _adopt(out);
    }
    return out;
  }

  // ── Lifecycle ──

  /// Dispose this [SignalResult] and release all listeners.
  ///
  /// Disposes the results derived from this one ([map] / [flatMap]) as well;
  /// disposing a derived result on its own detaches it from this one.
  /// Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final children = _children.toList(growable: false);
    _children.clear();
    for (final child in children) {
      child._parent = null;
      child.dispose();
    }
    _parent?._children.remove(this);
    _parent = null;
    _signal.dispose();
  }

  bool get isDisposed => _disposed || _signal.isDisposed;

  // ── Internal state ──

  /// Results derived from this one and still owned by it.
  final Set<SignalResult<dynamic>> _children = {};
  bool _disposed = false;

  /// The result this one was derived from, while that result still owns it.
  SignalResult<dynamic>? _parent;

  /// Take ownership of [child] so it is disposed with this result, and drop
  /// the ownership as soon as the child is disposed on its own.
  void _adopt(SignalResult<dynamic> child) {
    child._parent = this;
    _children.add(child);
  }
}
