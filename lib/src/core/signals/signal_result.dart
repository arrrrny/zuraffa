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
        innerSub = transform(r.value).listen((nr) => out.emit(nr));
      } else if (r is Failure<T, AppFailure>) {
        innerSub?.cancel();
        out.emitFailure(r.error);
      }
    });

    out._disposables.add(() {
      parentSub.cancel();
      innerSub?.cancel();
    });
    return out;
  }

  // ── Lifecycle ──

  /// Dispose this [SignalResult] and release all listeners.
  void dispose() {
    for (final fn in _disposables) {
      fn();
    }
    _disposables.clear();
    _signal.dispose();
  }

  bool get isDisposed => _signal.isDisposed;

  // ── Internal state ──

  final List<void Function()> _disposables = [];
}
