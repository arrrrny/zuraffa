import 'package:zuraffa/zuraffa.dart';

/// An observable cache that emits updates when entities change.
///
/// [CacheObserver] is the bridge between mutation UseCases and
/// listening SignalSlices. When a mutation updates the cache,
/// all observers for that entity type are notified.
///
/// ```dart
/// // Mutation UseCase
/// await updateProductUseCase.call(params);
/// CacheObserver.instance.notify<Product>(updatedProduct);
///
/// // View B's slice automatically receives the update
/// final slice = presenter.slice<Product>('product');
/// slice.listen((data, _) => print(data)); // fires with updatedProduct
/// ```
class CacheObserver {
  CacheObserver._();
  static final CacheObserver instance = CacheObserver._();

  final _streams = <Type, _CacheStream<dynamic>>{};

  /// Get or create the cache stream for type [T].
  _CacheStream<T> _streamFor<T>() {
    return _streams.putIfAbsent(T, () => _CacheStream<T>()) as _CacheStream<T>;
  }

  /// Notify all listeners that an entity of type [T] has been updated.
  void notify<T>(T entity) {
    _streamFor<T>().emit(entity);
  }

  /// Notify all listeners that an entity of type [T] has been deleted.
  void notifyDelete<T>(String id) {
    _streamFor<T>().emitDelete(id);
  }

  /// Listen to cache updates for type [T].
  ///
  /// Returns a [SignalSubscription] that can be cancelled.
  SignalSubscription listen<T>(
    void Function(T? entity, String? deletedId) callback,
  ) {
    return _streamFor<T>().listen(callback);
  }

  /// Dispose the stream for type [T]. Called when no views are active.
  void dispose<T>() {
    _streams[T]?.dispose();
    _streams.remove(T);
  }

  /// Whether any listeners are active for type [T].
  bool hasListeners<T>() => _streams[T]?.hasListeners ?? false;

  /// Clear all cached streams. Primarily for testing and app reset.
  void reset() {
    for (final stream in _streams.values) {
      stream.dispose();
    }
    _streams.clear();
  }
}

/// Internal cache stream for a single entity type.
class _CacheStream<T> {
  final _signal = Signal<_CacheEvent<T>?>(null);

  void emit(T entity) {
    _signal.value = _CacheEvent<T>(entity: entity);
  }

  void emitDelete(String id) {
    _signal.value = _CacheEvent<T>(deletedId: id);
  }

  SignalSubscription listen(
    void Function(T? entity, String? deletedId) callback,
  ) {
    return _signal.listen((event) {
      if (event != null) {
        callback(event.entity, event.deletedId);
      }
    });
  }

  bool get hasListeners => true; // Signal always has its internal listener

  void dispose() {
    _signal.dispose();
  }
}

class _CacheEvent<T> {
  _CacheEvent({this.entity, this.deletedId});
  final T? entity;
  final String? deletedId;
}
