import 'retry_policy.dart';

/// Exponential backoff retry policy — the OpenTelemetry standard convention.
///
/// Each retry waits progressively longer, with the delay multiplied
/// by [multiplier] after each attempt. The delay is capped at [maxInterval]
/// and retries stop after [maxRetries] attempts or [maxElapsed] time.
///
/// Default values follow the OTel OTLP exporter specification:
/// - multiplier: 1.5
/// - maxInterval: 30 seconds
/// - maxRetries: 5
/// - maxElapsed: 5 minutes (300 seconds)
///
/// ## Example
/// ```dart
/// final policy = ExponentialBackoffRetryPolicy(
///   multiplier: 2.0,
///   maxInterval: const Duration(seconds: 60),
///   maxRetries: 10,
/// );
/// ```
class ExponentialBackoffRetryPolicy extends ReportRetryPolicy {
  /// Multiplier applied to the delay after each retry.
  final double multiplier;

  /// Maximum delay between retries.
  final Duration maxInterval;

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Maximum total elapsed time for all retries.
  final Duration maxElapsed;

  /// Initial delay for the first retry.
  final Duration initialDelay;

  const ExponentialBackoffRetryPolicy({
    this.multiplier = 1.5,
    this.maxInterval = const Duration(seconds: 30),
    this.maxRetries = 5,
    this.maxElapsed = const Duration(seconds: 300),
    this.initialDelay = const Duration(seconds: 1),
  });

  @override
  Duration? nextDelay(int attemptNumber, Duration lastDelay) {
    if (attemptNumber >= maxRetries) return null;

    // First retry uses initial delay
    if (attemptNumber == 0) return initialDelay;

    // Subsequent retries use exponential backoff
    final nextMs = (lastDelay.inMilliseconds * multiplier).round();
    final next = Duration(milliseconds: nextMs);

    // Cap at max interval
    return next > maxInterval ? maxInterval : next;
  }
}

/// Fixed interval retry policy.
///
/// Retries with a constant delay between attempts.
///
/// ## Example
/// ```dart
/// final policy = FixedIntervalRetryPolicy(
///   interval: const Duration(seconds: 5),
///   maxRetries: 3,
/// );
/// ```
class FixedIntervalRetryPolicy extends ReportRetryPolicy {
  /// Constant delay between retries.
  final Duration interval;

  /// Maximum number of retry attempts.
  final int maxRetries;

  const FixedIntervalRetryPolicy({
    this.interval = const Duration(seconds: 5),
    this.maxRetries = 3,
  });

  @override
  Duration? nextDelay(int attemptNumber, Duration lastDelay) {
    if (attemptNumber >= maxRetries) return null;
    return interval;
  }
}

/// No retry policy — fire once, drop on failure.
///
/// Use when you want best-effort reporting without retries.
class NoRetryPolicy extends ReportRetryPolicy {
  const NoRetryPolicy();

  @override
  Duration? nextDelay(int attemptNumber, Duration lastDelay) => null;
}
