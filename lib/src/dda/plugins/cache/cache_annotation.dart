/// Annotation classes for the `@Cacheable` decorator-driven caching system.
///
/// Place `@Cacheable(ttl: Duration(hours: 1))` on a repository method, then
/// run `zfa build` to auto-generate the complete caching fallback logic.
library;

/// Caching strategy for a `@Cacheable` method.
///
/// Determines the order of cache vs. network operations.
enum CacheStrategy {
  /// Emit cached data immediately (if valid), then fetch network in
  /// the background. When the network response arrives, update the
  /// cache and push the fresh data to the UI via a [Signal].
  offlineFirst,

  /// Fetch from the network first. If the network call fails, fall
  /// back to the cached data (if any). On success, update the cache.
  networkFirst,

  /// Only read from the cache. Never make a network request.
  /// Useful for data that rarely changes or offline-only views.
  cacheOnly,

  /// Skip the cache entirely. Always fetch from the network.
  /// Equivalent to not using `@Cacheable` at all.
  networkOnly;
}

/// Marks a repository or datasource method for auto-generated caching.
///
/// When attached to a method, `zfa build` writes a caching wrapper that
/// implements the selected [strategy]:
///
/// - **offlineFirst** (default): check cache → emit cached data as [Signal]
///   → fetch network in background → update cache → push new [Signal] to UI.
/// - **networkFirst**: fetch network → on success update cache → on failure
///   fallback to cache.
/// - **cacheOnly**: return cached data or `null`.
/// - **networkOnly**: no caching, pass through.
///
/// ```dart
/// class ProductRepositoryImpl implements ProductRepository {
///   final ProductRemoteDatasource _remote;
///   final CacheStore _cache;
///
///   @Cacheable(ttl: Duration(hours: 1), strategy: CacheStrategy.offlineFirst)
///   Future<Product> getProduct(String id) async {
///     return _remote.getProduct(id);
///   }
/// }
/// ```
///
/// The DDA pipeline scans for `@Cacheable` annotations and generates
/// a wrapper method that handles cache read/write/invalidate logic
/// automatically.
class Cacheable {
  /// Time-to-live for cached entries. Expired entries are skipped
  /// and fresh data is fetched instead.
  ///
  /// When `null`, the default TTL is hardcoded to 24 hours.
  /// The cache is managed via `ZfaCacheStore` and invalidation
  /// uses `_store.invalidateByPrefix(prefix)`.
  final Duration? ttl;

  /// Caching strategy. Defaults to [CacheStrategy.offlineFirst].
  final CacheStrategy strategy;

  /// Optional cache key prefix. When set, overrides the auto-generated
  /// key (which is derived from the method name + arguments).
  ///
  /// ```dart
  /// @Cacheable(keyPrefix: 'product_list')
  /// Future<List<Product>> getProducts() async { ... }
  /// // Cache key (no args): "product_list"
  /// // Cache key (with args): "product_list:arg1:arg2"
  /// ```
  final String? keyPrefix;

  /// The Hive box name to use for storing cached data.
  /// Defaults to the entity snake-case name + '_cache'.
  final String? boxName;

  const Cacheable({
    this.ttl,
    this.strategy = CacheStrategy.offlineFirst,
    this.keyPrefix,
    this.boxName,
  });
}

/// Marks a method as a cache invalidator.
///
/// When placed on a method (e.g., `updateProduct`, `deleteProduct`),
/// `zfa build` generates cache-invalidation calls that clear entries
/// for the specified target methods.
///
/// ```dart
/// @CacheInvalidate(methods: ['getProduct', 'getProductList'])
/// Future<void> updateProduct(Product product) async {
///   return _remote.updateProduct(product);
/// }
/// ```
///
/// The generated wrapper calls `CachePolicy.invalidate(key)` for each
/// target method's cache key after the original method completes
/// successfully.
class CacheInvalidate {
  /// Method names whose cache entries should be cleared when this
  /// method executes successfully.
  ///
  /// Keys are method names (e.g., `getProduct`, `getProductList`).
  final List<String> methods;

  /// Optional cache key prefix for the invalidated entries.
  /// When set, overrides the auto-generated prefix.
  final String? keyPrefix;

  const CacheInvalidate({
    required this.methods,
    this.keyPrefix,
  });
}
