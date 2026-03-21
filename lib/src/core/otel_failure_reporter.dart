import 'package:opentelemetry/api.dart'
    show
        Attribute,
        StatusCode,
        globalTracerProvider,
        registerGlobalTracerProvider,
        Tracer;
import 'package:opentelemetry/sdk.dart'
    show BatchSpanProcessor, CollectorExporter, TracerProviderBase;

import 'failure.dart';
import 'failure_reporter.dart';

/// OpenTelemetry failure reporter — shipped opinionated with Zuraffa.
///
/// Maps each [AppFailure] to an OTel Span with error status and enriched
/// attributes. Uses [BatchSpanProcessor] + [CollectorExporter] for efficient
/// delivery to any OTLP-compatible collector.
///
/// ## Usage
/// ```dart
/// Zuraffa.addFailureReporter(
///   OtelFailureReporter(
///     collectorEndpoint: Uri.parse('https://otel.mybackend.com/v1/traces'),
///     serviceName: 'my_app',
///   ),
/// );
/// ```
///
/// ## Attributes
/// Each span includes:
/// - `failure.type`: The runtime type of the failure (e.g., `ServerFailure`)
/// - `failure.message`: The failure message
/// - `failure.cause`: The original cause (if any)
/// - Custom attributes from the [FailureReport]
/// - Failure-specific attributes (e.g., `http.status_code` for ServerFailure)
class OtelFailureReporter extends FailureReporter {
  /// The OTLP collector endpoint (e.g., `https://otel.example.com/v1/traces`).
  final Uri collectorEndpoint;

  /// The service name to identify this application in traces.
  final String serviceName;

  /// Optional instrumentation name (defaults to `zuraffa-failure-reporter`).
  final String instrumentationName;

  late final Tracer _tracer;

  @override
  String get id => 'zuraffa-otel';

  OtelFailureReporter({
    required this.collectorEndpoint,
    required this.serviceName,
    this.instrumentationName = 'zuraffa-failure-reporter',
  });

  @override
  Future<void> initialize() async {
    final tracerProvider = TracerProviderBase(
      processors: [
        BatchSpanProcessor(CollectorExporter(collectorEndpoint)),
      ],
    );

    try {
      registerGlobalTracerProvider(tracerProvider);
    } on StateError {
      // Already registered — reuse the existing global provider.
      // This happens when multiple OtelFailureReporters are created
      // (e.g., in tests) or when the app re-initializes.
    }
    _tracer = globalTracerProvider.getTracer(instrumentationName);
  }

  @override
  Future<void> reportBatch(List<FailureReport> reports) async {
    for (final report in reports) {
      final span = _tracer.startSpan(
        'failure.${report.failure.runtimeType}',
      );

      try {
        // Set error status
        span.setStatus(StatusCode.error, report.failure.message);

        // Core attributes
        span.setAttribute(Attribute.fromString(
            'failure.type', report.failure.runtimeType.toString()));
        span.setAttribute(
            Attribute.fromString('failure.message', report.failure.message));
        span.setAttribute(Attribute.fromString(
            'failure.timestamp', report.timestamp.toIso8601String()));

        if (report.failure.cause != null) {
          span.setAttribute(Attribute.fromString(
              'failure.cause', report.failure.cause.toString()));
        }

        // Failure-specific attributes
        _addFailureAttributes(span, report.failure);

        // User-provided attributes
        if (report.attributes != null) {
          for (final entry in report.attributes!.entries) {
            span.setAttribute(
                Attribute.fromString(entry.key, entry.value.toString()));
          }
        }

        // Record exception with stack trace
        final st = report.stackTrace;
        if (st != null) {
          span.recordException(
            report.failure,
            stackTrace: st,
          );
        }
      } finally {
        span.end();
      }
    }
  }

  /// Add failure-type-specific attributes to the span.
  void _addFailureAttributes(dynamic span, AppFailure failure) {
    switch (failure) {
      case ServerFailure(:final statusCode):
        if (statusCode != null) {
          span.setAttribute(
              Attribute.fromInt('http.status_code', statusCode));
        }
      case NetworkFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'network'));
      case ValidationFailure(:final fieldErrors):
        span.setAttribute(
            Attribute.fromString('failure.category', 'validation'));
        if (fieldErrors != null) {
          span.setAttribute(Attribute.fromString(
              'failure.fields', fieldErrors.keys.join(',')));
        }
      case NotFoundFailure(:final resourceType, :final resourceId):
        span.setAttribute(
            Attribute.fromString('failure.category', 'not_found'));
        if (resourceType != null) {
          span.setAttribute(
              Attribute.fromString('failure.resource_type', resourceType));
        }
        if (resourceId != null) {
          span.setAttribute(
              Attribute.fromString('failure.resource_id', resourceId));
        }
      case UnauthorizedFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'auth'));
        span.setAttribute(
            Attribute.fromString('failure.auth_type', 'unauthorized'));
      case ForbiddenFailure(:final requiredPermission):
        span.setAttribute(
            Attribute.fromString('failure.category', 'auth'));
        span.setAttribute(
            Attribute.fromString('failure.auth_type', 'forbidden'));
        if (requiredPermission != null) {
          span.setAttribute(Attribute.fromString(
              'failure.required_permission', requiredPermission));
        }
      case TimeoutFailure(:final timeout):
        span.setAttribute(
            Attribute.fromString('failure.category', 'timeout'));
        if (timeout != null) {
          span.setAttribute(Attribute.fromInt(
              'failure.timeout_ms', timeout.inMilliseconds));
        }
      case ConflictFailure(:final conflictType):
        span.setAttribute(
            Attribute.fromString('failure.category', 'conflict'));
        if (conflictType != null) {
          span.setAttribute(
              Attribute.fromString('failure.conflict_type', conflictType));
        }
      case CacheFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'cache'));
      case PlatformFailure(:final code):
        span.setAttribute(
            Attribute.fromString('failure.category', 'platform'));
        if (code != null) {
          span.setAttribute(
              Attribute.fromString('failure.platform_code', code));
        }
      case CancellationFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'cancellation'));
      case StateFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'state'));
      case TypeFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'type'));
      case UnimplementedFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'unimplemented'));
      case UnsupportedFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'unsupported'));
      case UnknownFailure():
        span.setAttribute(
            Attribute.fromString('failure.category', 'unknown'));
    }
  }

  @override
  Future<void> dispose() async {
    // TracerProviderBase handles flushing pending spans
  }
}
