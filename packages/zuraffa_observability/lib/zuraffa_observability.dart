/// OpenTelemetry capability for Zuraffa (optional companion package).
///
/// Spec 1653-trim-heavy-deps (issue #1661): the otel-backed tracer,
/// failure reporter, telemetry hook, and simulation span capture moved
/// out of the core package. Core keeps the light `TraceObserver` seam —
/// call `ZuraffaObservability.init` to wire the otel-backed observer.
library;

export 'src/facade.dart';
export 'src/otel_adapter.dart';
export 'src/otel_failure_reporter.dart';
export 'src/otel_tracer.dart';
export 'src/telemetry_hook.dart';
