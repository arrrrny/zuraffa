/// @zuraffa annotation for generating providers
///
/// Mark functions or classes with @zuraffa to generate providers automatically.
///
/// Example:
/// ```dart
/// @zuraffa
/// Future<Product> getProduct(ZuraffaRef ref, String id) async {
///   final repo = ref.read(productRepositoryProvider);
///   return await repo.getById(id);
/// }
/// ```
///
/// Generated code:
/// ```dart
/// final getProductProvider = ZuraffaProviderFamily<Product, String>(
///   (ref, id) => getProduct(ref, id),
/// );
/// ```
class Zuraffa {
  /// Optional retry strategy for this provider
  final RetryStrategy? retry;

  /// Optional cache duration
  final Duration? cache;

  /// Optional dependencies that trigger rebuild
  final List<Object>? dependencies;

  const Zuraffa({
    this.retry,
    this.cache,
    this.dependencies,
  });
}

/// Shorthand annotation
const zuraffa = Zuraffa();

/// Retry strategy function type
///
/// Returns the duration to wait before retrying, or null to stop retrying.
///
/// Parameters:
/// - retryCount: The number of retries so far (starts at 1)
/// - error: The error that occurred
///
/// Example:
/// ```dart
/// Duration? myRetry(int retryCount, Object error) {
///   if (retryCount > 5) return null; // Max 5 retries
///   if (error is NetworkFailure) {
///     return Duration(seconds: retryCount * 2); // Exponential backoff
///   }
///   return null; // Don't retry other errors
/// }
/// ```
typedef RetryStrategy = Duration? Function(int retryCount, Object error);

/// Default retry strategy with exponential backoff
///
/// Retries up to 3 times with delays of 1s, 2s, 4s
Duration? defaultRetryStrategy(int retryCount, Object error) {
  if (retryCount > 3) return null;
  return Duration(seconds: 1 << (retryCount - 1)); // 2^(n-1) seconds
}

/// Aggressive retry strategy
///
/// Retries up to 5 times with longer delays
Duration? aggressiveRetryStrategy(int retryCount, Object error) {
  if (retryCount > 5) return null;
  return Duration(seconds: retryCount * 2);
}

/// No retry - fail immediately
Duration? noRetryStrategy(int retryCount, Object error) => null;
