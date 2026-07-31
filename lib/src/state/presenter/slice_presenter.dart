import 'dart:collection';
import 'package:zuraffa/zuraffa.dart';

import '../slices/signal_slice.dart';

/// A presenter that manages multiple [SignalSlice]s — one per UseCase.
///
/// Replaces the monolithic v5 state object. Each slice is independent,
/// so widgets rebuild only when their subscribed slice changes.
///
/// ## Backward Compatibility
///
/// [combinedState] exposes all slices as a single map for views that
/// haven't migrated yet. Accessing it is O(N) in slice count but
/// only recomputes when any slice changes.
///
/// ```dart
/// class ProductPresenter extends SlicePresenter {
///   late final productSlice = bind(
///     'product',
///     getProductUseCase,
///     GetProductParams(id: '123'),
///   );
///
///   late final reviewsSlice = bind(
///     'reviews',
///     getReviewsUseCase,
///     GetReviewsParams(productId: '123'),
///   );
/// }
/// ```
abstract class SlicePresenter {
  SlicePresenter({ZuraffaContext? context})
    : _context = context ?? ZuraffaContext.noop;

  final ZuraffaContext _context;
  final _slices = HashMap<String, SignalSlice<dynamic>>();
  Signal<Map<String, dynamic>>? _combinedState;
  bool _disposed = false;

  // ── Slice binding ──

  /// Bind a [useCase] to a named [sliceKey].
  ///
  /// The slice is lazily executed on first access.
  SignalSlice<T> bind<T>(
    String sliceKey,
    ZuraffaUseCase<dynamic, T> useCase,
    dynamic params,
  ) {
    _assertNotDisposed();
    if (_slices.containsKey(sliceKey)) {
      throw StateError('Slice "$sliceKey" is already bound.');
    }
    final slice = SignalSlice<T>(
      useCase: useCase,
      params: params,
      context: _context,
    );
    _slices[sliceKey] = slice;
    _invalidateCombinedState();
    return slice;
  }

  /// Get a previously bound slice by key.
  SignalSlice<T>? slice<T>(String sliceKey) {
    _assertNotDisposed();
    return _slices[sliceKey] as SignalSlice<T>?;
  }

  /// All bound slice keys.
  Set<String> get sliceKeys => Set.unmodifiable(_slices.keys);

  /// Number of bound slices.
  int get sliceCount => _slices.length;

  // ── Backward compatibility: combined state ──

  /// A combined signal of all slice states as a map.
  ///
  /// ```dart
  /// { 'product': Product?, 'reviews': List<Review>? }
  /// ```
  ///
  /// This is O(N) to read but cached until any slice changes.
  /// Prefer accessing individual slices for O(1) performance.
  ReadonlySignal<Map<String, dynamic>> get combinedState {
    _assertNotDisposed();
    _combinedState ??= _buildCombinedSignal();
    return _combinedState!;
  }

  Signal<Map<String, dynamic>> _buildCombinedSignal() {
    // Start with current values
    final initial = <String, dynamic>{
      for (final entry in _slices.entries) entry.key: entry.value.data,
    };
    final combined = Signal<Map<String, dynamic>>(initial);

    // Subscribe to each slice and update the combined map
    for (final entry in _slices.entries) {
      entry.value.listen((data, _) {
        combined.update(
          (map) => Map<String, dynamic>.from(map)..[entry.key] = data,
        );
      });
    }

    return combined;
  }

  void _invalidateCombinedState() {
    _combinedState?.dispose();
    _combinedState = null;
  }

  // ── Batch operations ──

  /// Refresh all slices with their current params.
  void refreshAll() {
    _assertNotDisposed();
    for (final slice in _slices.values) {
      slice.refresh();
    }
  }

  /// Dispose all slices and the presenter.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidateCombinedState();
    for (final slice in _slices.values) {
      slice.dispose();
    }
    _slices.clear();
  }

  bool get isDisposed => _disposed;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('SlicePresenter has been disposed.');
  }
}
