/// Abstract retry strategy for failure report delivery.
///
/// Determines the delay between retry attempts when a [FailureReporter]
/// fails to deliver a batch. Follows the same strategy pattern as
/// [CachePolicy].
///
/// Zuraffa ships with three implementations:
/// - [ExponentialBackoffRetryPolicy] — OTel standard (default)
/// - [FixedIntervalRetryPolicy] — constant delay between retries
/// - [NoRetryPolicy] — fire once, drop on failure
///
/// ## Custom Implementation
/// ```dart
/// class LinearBackoffRetryPolicy implements ReportRetryPolicy {
///   @override
///   Duration? nextDelay(int attemptNumber, Duration lastDelay) {
///     if (attemptNumber >= 10) return null; // give up
///     return Duration(seconds: attemptNumber * 2);
///   }
/// }
/// ```
abstract class ReportRetryPolicy {
  const ReportRetryPolicy();

  /// Calculate the delay before the next retry attempt.
  ///
  /// Returns `null` to indicate that retries should stop (give up).
  ///
  /// - [attemptNumber]: 0-indexed retry attempt (0 = first retry)
  /// - [lastDelay]: the delay used for the previous attempt
  ///   (for the first retry, this is [Duration.zero])
  Duration? nextDelay(int attemptNumber, Duration lastDelay);
}
