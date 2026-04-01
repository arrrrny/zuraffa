import 'failure.dart';

/// A single failure report with context.
///
/// Created when an [AppFailure] is captured and enqueued for reporting.
/// Contains the failure, timestamp, stack trace, and optional attributes
/// for enriching the report (e.g., UseCase name, user ID).
class FailureReport {
  /// The failure that occurred.
  final AppFailure failure;

  /// When the failure occurred.
  final DateTime timestamp;

  /// Stack trace from where the failure originated.
  final StackTrace? stackTrace;

  /// Optional attributes to enrich the report.
  ///
  /// Examples: `{'usecase': 'GetProductUseCase', 'userId': '123'}`
  final Map<String, String>? attributes;

  const FailureReport({
    required this.failure,
    required this.timestamp,
    this.stackTrace,
    this.attributes,
  });

  @override
  String toString() =>
      'FailureReport(${failure.runtimeType}: ${failure.message}, '
      'at: $timestamp)';
}

/// Abstract contract for reporting failures to external systems.
///
/// Implement this to send failures to any backend:
/// OpenTelemetry, Sentry, custom HTTP endpoints, etc.
///
/// Zuraffa ships with [OtelFailureReporter] as the opinionated default.
///
/// ## Example
/// ```dart
/// class MyCustomReporter extends FailureReporter {
///   @override
///   String get id => 'my-custom-reporter';
///
///   @override
///   Future<void> reportBatch(List<FailureReport> reports) async {
///     for (final report in reports) {
///       await myHttpClient.post('/errors', body: {
///         'type': report.failure.runtimeType.toString(),
///         'message': report.failure.message,
///         'timestamp': report.timestamp.toIso8601String(),
///       });
///     }
///   }
/// }
/// ```
abstract class FailureReporter {
  /// Unique identifier for this reporter.
  String get id;

  /// Whether this reporter should handle the given failure.
  ///
  /// Override to filter by failure type, severity, etc.
  /// By default, reports all failures except [CancellationFailure].
  bool shouldReport(AppFailure failure) => failure is! CancellationFailure;

  /// Report a batch of failures to an external system.
  ///
  /// This is called by the [FailureReportQueue] during flush.
  /// **Throwing an exception signals a retryable failure** —
  /// the batch will be retried according to the configured [ReportRetryPolicy].
  Future<void> reportBatch(List<FailureReport> reports);

  /// Called once when the reporter is registered.
  ///
  /// Use for initialization (e.g., setting up OTel TracerProvider).
  Future<void> initialize() async {}

  /// Called on app shutdown or when the reporter is unregistered.
  ///
  /// Use for cleanup (e.g., flushing pending data, closing connections).
  Future<void> dispose() async {}
}
