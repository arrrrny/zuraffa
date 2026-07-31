import 'package:zuraffa/zuraffa.dart';

/// A fine-grained reactive slice that wraps a [SignalResult<T>].
///
/// [SignalSlice] is the v6 replacement for monolithic `.state.dart` objects.
/// Each UseCase gets its own slice, so UI rebuilds are O(1) and isolated.
///
/// ```dart
/// final productSlice = SignalSlice<Product>(
///   useCase: getProductUseCase,
///   params: GetProductParams(id: '123'),
/// );
///
/// // Subscribe to ONLY this slice
/// productSlice.listen((product) => setState(() => _product = product));
/// ```
class SignalSlice<T> {
  SignalSlice({
    required ZuraffaUseCase<dynamic, T> useCase,
    required dynamic params,
    ZuraffaContext? context,
  }) : _useCase = useCase,
       _params = params,
       _context = context ?? ZuraffaContext.noop;

  final ZuraffaUseCase<dynamic, T> _useCase;
  dynamic _params;
  final ZuraffaContext _context;

  SignalResult<T>? _result;
  bool _disposed = false;

  /// Registered listeners with their current result subscription.
  final List<_SliceListener<T>> _listeners = [];

  /// Cache subscriptions created via [CacheBinding.bindCache]; cancelled
  /// when the slice is disposed so disposed slices do not keep callbacks
  /// registered on the type-level cache stream.
  final List<SignalSubscription> _cacheSubscriptions = [];

  // ── Lazy execution ──

  /// The underlying [SignalResult]. Lazily created on first access.
  SignalResult<T> get result {
    _assertNotDisposed();
    _result ??= _useCase.call(_params, context: _context);
    return _result!;
  }

  // ── Read API ──

  /// Current data if success, otherwise null.
  T? get data => result.data;

  /// Current error if failure, otherwise null.
  AppFailure? get error => result.error;

  /// Whether the slice is in loading state.
  bool get isLoading => result.isLoading;

  /// Whether the slice has succeeded.
  bool get isSuccess => result.isSuccess;

  /// Whether the slice has failed.
  bool get isFailure => result.isFailure;

  // ── Subscription API ──

  /// Subscribe to changes on this slice only. Other slices are unaffected.
  SignalSubscription listen(
    void Function(T? data, AppFailure? error) callback,
  ) {
    _assertNotDisposed();
    final listener = _SliceListener<T>(callback);
    _listeners.add(listener);
    listener.subscription = result.listen(
      (res) => listener.callback(res.getOrNull(), res.getFailureOrNull()),
    );
    return SignalSubscription(() => _removeListener(listener));
  }

  /// Subscribe only to success values.
  SignalSubscription onSuccess(void Function(T data) callback) {
    return listen((data, _) {
      if (data != null) callback(data);
    });
  }

  /// Subscribe only to failures.
  SignalSubscription onFailure(void Function(AppFailure error) callback) {
    return listen((_, error) {
      if (error != null) callback(error);
    });
  }

  // ── Execution control ──

  /// Re-execute the underlying use case with new params.
  void refresh([dynamic newParams]) {
    _assertNotDisposed();
    if (newParams != null) _params = newParams;
    _result?.dispose();
    _result = _useCase.call(_params, context: _context);
    _reattachListeners();
  }

  /// Registers a subscription to be cancelled when this slice is disposed.
  ///
  /// Used by [CacheBinding.bindCache] so disposed slices do not keep
  /// callbacks registered on the type-level cache stream. If the slice is
  /// already disposed, the subscription is cancelled immediately — the
  /// disposal path has already cleared the tracked list.
  void trackCacheSubscription(SignalSubscription sub) {
    if (_disposed) {
      sub.cancel();
      return;
    }
    _cacheSubscriptions.add(sub);
  }

  // ── Lifecycle ──

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final listener in _listeners) {
      listener.subscription?.cancel();
    }
    _listeners.clear();
    for (final sub in _cacheSubscriptions) {
      sub.cancel();
    }
    _cacheSubscriptions.clear();
    _result?.dispose();
    _result = null;
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('SignalSlice has been disposed.');
  }

  void _removeListener(_SliceListener<T> listener) {
    _listeners.remove(listener);
    listener.subscription?.cancel();
  }

  void _reattachListeners() {
    final current = _result!;
    for (final listener in _listeners) {
      // Cancel the old subscription and subscribe to the new result.
      listener.subscription?.cancel();
      listener.subscription = current.listen(
        (res) => listener.callback(res.getOrNull(), res.getFailureOrNull()),
      );
    }
  }

  @override
  String toString() =>
      'SignalSlice<$T>(loading=$isLoading, success=$isSuccess, failure=$isFailure)';
}

/// Internal listener wrapper: tracks the current subscription so that
/// cancelling the handle stops whichever subscription is active.
class _SliceListener<T> {
  _SliceListener(this.callback);
  final void Function(T? data, AppFailure? error) callback;
  SignalSubscription? subscription;
}
