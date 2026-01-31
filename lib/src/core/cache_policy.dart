/// Cache policy abstraction for determining cache validity.
///
/// Implement this interface to define custom cache expiration strategies.
abstract class CachePolicy {
  /// Check if cached data for [key] is still valid.
  Future<bool> isValid(String key);

  /// Mark cached data for [key] as fresh.
  Future<void> markFresh(String key);

  /// Invalidate cached data for [key].
  Future<void> invalidate(String key);

  /// Clear all cached data.
  Future<void> clear();
}
