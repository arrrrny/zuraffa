import 'package:zuraffa/zuraffa.dart';

import 'cache_observer.dart';

/// Binds a [SignalSlice<T>] to the [CacheObserver] for automatic
/// cross-view state synchronization.
///
/// When the cache emits an update for type [T], the slice's
/// [SignalResult] is updated automatically — no network re-fetch.
///
/// ```dart
/// // In generated DomainState:
/// final product = bind<Product>('product', getProductUseCase, params)
///   ..bindCache(); // auto-generated for @Cacheable entities
/// ```
extension CacheBinding<T> on SignalSlice<T> {
  /// Subscribe this slice to cache updates for type [T].
  ///
  /// When the cache emits a new entity, the slice's result is
  /// updated with [Success]. When a delete is emitted, the slice
  /// transitions to a null data state.
  ///
  /// Returns the [SignalSubscription] for the cache listener.
  /// The subscription is automatically cancelled when the slice
  /// is disposed.
  SignalSubscription bindCache() {
    return CacheObserver.instance.listen<T>((entity, deletedId) {
      // Ignore cache events after the slice has been disposed.
      if (isDisposed) return;
      if (deletedId != null) {
        // Entity was deleted — signal a failure state (type-safe for
        // non-nullable [T], which cannot represent a null data value).
        result.emitFailure(UnknownFailure('Entity deleted: $deletedId'));
      } else if (entity != null) {
        // Entity updated — push new data
        result.emitSuccess(entity);
      }
    });
  }
}

/// Mixin for UseCases that update the cache after mutation.
///
/// ```dart
/// class UpdateProductUseCase extends ZuraffaUseCase<...>
///     with CacheMutator<Product> {
///   @override
///   SignalResult<Product> call(params) {
///     // ... perform mutation ...
///     final updated = await api.update(params);
///     notifyCache(updated); // View B receives update automatically
///     return SignalResult.success(updated);
///   }
/// }
/// ```
mixin CacheMutator<T> {
  /// Notify the cache that an entity has been updated.
  void notifyCache(T entity) {
    CacheObserver.instance.notify<T>(entity);
  }

  /// Notify the cache that an entity has been deleted.
  void notifyCacheDelete(String id) {
    CacheObserver.instance.notifyDelete<T>(id);
  }
}
