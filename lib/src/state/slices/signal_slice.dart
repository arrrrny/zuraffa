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

  /// Active subscriptions. Re-attached to the current result on refresh.
  final List<void Function(T? data, AppFailure? error)> _listeners = [];
  final List<SignalSubscription> _activeSubscriptions = [];

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
    _listeners.add(callback);
    final sub = result.listen((res) {
      callback(res.getOrNull(), res.getFailureOrNull());
    });
    _activeSubscriptions.add(sub);
    return SignalSubscription(() {
      _listeners.remove(callback);
      sub.cancel();
    });
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

  // ── Lifecycle ──

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _activeSubscriptions) {
      sub.cancel();
    }
    _activeSubscriptions.clear();
    _listeners.clear();
    _result?.dispose();
    _result = null;
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('SignalSlice has been disposed.');
  }

  void _reattachListeners() {
    _activeSubscriptions.clear();
    for (final listener in _listeners) {
      final sub = _result!.listen((res) {
        listener(res.getOrNull(), res.getFailureOrNull());
      });
      _activeSubscriptions.add(sub);
    }
  }

  @override
  String toString() =>
      'SignalSlice<$T>(loading=$isLoading, success=$isSuccess, failure=$isFailure)';
}
