import 'dart:async';

import '../failure.dart';
import '../signals/signal_result.dart';
import '../signals/signal.dart';
import '../context/zuraffa_context.dart';
import '../result.dart';

/// Base contract for all zuraffa use cases (v6).
///
/// The return type is [SignalResult<T>] instead of the v5 `Stream<Result<T, AppFailure>>`.
/// This provides:
///
/// - O(1) reads of the current result
/// - Fine-grained reactive subscriptions
/// - Zero stream overhead for single-shot use cases
///
/// ## Migration from v5
///
/// ```dart
/// // v5
/// Stream<Result<Product, AppFailure>> call(GetProductParams params);
///
/// // v6
/// SignalResult<Product> call(GetProductParams params, {ZuraffaContext? context});
/// ```
///
/// The [context] parameter is optional and defaults to [ZuraffaContext.noop].
abstract class ZuraffaUseCase<In, Out> {
  const ZuraffaUseCase();

  /// Execute the use case.
  ///
  /// Returns a [SignalResult] that starts as [LoadingResult] and transitions
  /// to [Success] or [Failure] when the operation completes.
  SignalResult<Out> call(In params, {ZuraffaContext? context});
}

/// Mixin for use cases that need manual disposal of internal signals.
///
/// Call [disposeUseCase] when the use case is no longer needed (e.g. widget
/// unmount) to prevent memory leaks.
mixin DisposableUseCase<In, Out> on ZuraffaUseCase<In, Out> {
  final List<SignalResult<dynamic>> _ownedResults = [];

  /// Register a [SignalResult] that this use case owns.
  /// It will be disposed when [disposeUseCase] is called.
  SignalResult<T> own<T>(SignalResult<T> result) {
    _ownedResults.add(result);
    return result;
  }

  /// Dispose all owned signal results.
  void disposeUseCase() {
    for (final r in _ownedResults) {
      r.dispose();
    }
    _ownedResults.clear();
  }
}

/// Adapter for migrating v5 `Stream<Result<T, AppFailure>>` use cases to v6.
///
/// Wraps a stream in a [SignalResult] and bridges emissions.
/// This is a temporary migration helper — prefer native [SignalResult]
/// implementations for new use cases.
class StreamToSignalResultAdapter<T> {
  /// Convert a stream to a [SignalResult].
  ///
  /// The returned [SignalResult] is automatically disposed when the stream
  /// completes or emits an error. If you need long-lived subscriptions, use
  /// [SignalResult.fromFuture] or native signals instead.
  static SignalResult<T> adapt<T>(Stream<Result<T, AppFailure>> stream) {
    final sr = SignalResult<T>.initial(LoadingResult<T, AppFailure>.loading());
    _DisposableSignalResult<T>? wrapper;

    final sub = stream.listen(
      (result) => sr.emit(result),
      onError: (Object e, StackTrace st) {
        sr.emitFailure(AppFailure.from(e, st));
        wrapper?.dispose();
      },
      onDone: () {
        if (!sr.isSuccess && !sr.isFailure) {
          sr.emitFailure(UnknownFailure('Stream completed without result'));
        }
        wrapper?.dispose();
      },
    );

    wrapper = _DisposableSignalResult(sr, sub);
    return wrapper;
  }
}

/// A [SignalResult] wrapper that cancels an underlying stream subscription
/// when disposed. Used by [StreamToSignalResultAdapter].
class _DisposableSignalResult<T> implements SignalResult<T> {
  _DisposableSignalResult(this._delegate, this._subscription);

  final SignalResult<T> _delegate;
  final StreamSubscription<Result<T, AppFailure>> _subscription;

  bool _disposed = false;

  @override
  Result<T, AppFailure> get value => _delegate.value;
  @override
  T? get data => _delegate.data;
  @override
  AppFailure? get error => _delegate.error;
  @override
  bool get isLoading => _delegate.isLoading;
  @override
  bool get isSuccess => _delegate.isSuccess;
  @override
  bool get isFailure => _delegate.isFailure;
  @override
  bool get isDisposed => _disposed;

  @override
  void emit(Result<T, AppFailure> result) => _delegate.emit(result);
  @override
  void emitSuccess(T value) => _delegate.emitSuccess(value);
  @override
  void emitFailure(AppFailure error) => _delegate.emitFailure(error);
  @override
  void emitLoading() => _delegate.emitLoading();
  @override
  void update(
    Result<T, AppFailure> Function(Result<T, AppFailure> current) updater,
  ) => _delegate.update(updater);
  @override
  void updateData(T Function(T currentData) updater) =>
      _delegate.updateData(updater);

  @override
  SignalSubscription listen(
    void Function(Result<T, AppFailure> result) callback,
  ) => _delegate.listen(callback);
  @override
  SignalSubscription onSuccess(void Function(T value) callback) =>
      _delegate.onSuccess(callback);
  @override
  SignalSubscription onFailure(void Function(AppFailure error) callback) =>
      _delegate.onFailure(callback);

  @override
  Future<Result<T, AppFailure>> get nextValue => _delegate.nextValue;

  @override
  SignalResult<R> map<R>(R Function(T value) transform) =>
      _delegate.map(transform);
  @override
  SignalResult<R> flatMap<R>(SignalResult<R> Function(T value) transform) =>
      _delegate.flatMap(transform);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription.cancel();
    _delegate.dispose();
  }
}
