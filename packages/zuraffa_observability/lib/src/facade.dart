import 'package:zuraffa/zuraffa.dart';

import 'otel_failure_reporter.dart';
import 'otel_tracer.dart';

/// Facade for the observability capability.
///
/// The core `Zuraffa.enableOtelReporting(...)` convenience moved here
/// (spec 1653-trim-heavy-deps, issue #1661): call [init] plus
/// [enableOtelReporting] during startup after `Zuraffa.init`.
class ZuraffaObservability {
  ZuraffaObservability._();

  /// Wires the otel-backed [TraceObserver] so core hooks and use cases
  /// surface real trace/span ids.
  static void init() {
    TraceObserver.instance = OtelTracer.instance;
  }

  /// One-call OpenTelemetry failure reporting (the former
  /// `Zuraffa.enableOtelReporting`).
  static Future<void> enableOtelReporting({
    required Uri collectorEndpoint,
    required String serviceName,
    String? apiKey,
    ReportRetryPolicy? retryPolicy,
    int? maxQueueSize,
    Duration? flushInterval,
    bool persistFailures = false,
  }) async {
    await Zuraffa.addFailureReporter(
      OtelFailureReporter(
        collectorEndpoint: collectorEndpoint,
        serviceName: serviceName,
        apiKey: apiKey,
      ),
      retryPolicy: retryPolicy,
      maxQueueSize: maxQueueSize,
      flushInterval: flushInterval,
      persistFailures: persistFailures,
    );
  }
}
