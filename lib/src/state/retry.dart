import 'zuraffa_annotation.dart';

/// Retry executor for async operations
///
/// Wraps a Future and automatically retries on failure according to the retry strategy.
class RetryExecutor {
  final RetryStrategy strategy;

  const RetryExecutor(this.strategy);

  /// Execute a future with retry logic
  Future<T> execute<T>(Future<T> Function() fn) async {
    int retryCount = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    while (true) {
      try {
        return await fn();
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        // Ask strategy if we should retry
        final delay = strategy(retryCount + 1, error);

        if (delay == null) {
          // No more retries, throw the error
          Error.throwWithStackTrace(error, stackTrace);
        }

        // Wait before retry
        retryCount++;
        await Future.delayed(delay);

        // Continue to next iteration (retry)
      }
    }
  }
}

/// Extension for adding retry to futures
extension RetryFutureExtension<T> on Future<T> {
  /// Retry this future with the given strategy
  ///
  /// Example:
  /// ```dart
  /// final result = await api.fetchData().withRetry(defaultRetryStrategy);
  /// ```
  Future<T> withRetry(RetryStrategy strategy) {
    return RetryExecutor(strategy).execute(() => this);
  }

  /// Retry with exponential backoff (3 retries max)
  Future<T> withDefaultRetry() {
    return withRetry(defaultRetryStrategy);
  }

  /// Retry aggressively (5 retries with longer delays)
  Future<T> withAggressiveRetry() {
    return withRetry(aggressiveRetryStrategy);
  }
}
