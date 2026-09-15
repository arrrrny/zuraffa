import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:zuraffa/zuraffa.dart' show SimulationSpanCapture, SpanSnapshot;

/// Certified OpenTelemetry simulation: a capture-and-assert exporter.
///
/// Implements the REAL production [otel_sdk.SpanExporter] interface — the
/// same interface the live OTLP/collector exporter implements — so
/// `TelemetryHook`/`OtelTracer` pipelines run unchanged against it and
/// every span ends up asserted from memory instead of shipped over the
/// network. Moved here from the core simulation module by
/// spec 1653-trim-heavy-deps (issue #1661): core consumes the light
/// [SimulationSpanCapture] seam, the vendor-typed exporter lives here.
final class OtelAdapter
    implements otel_sdk.SpanExporter, SimulationSpanCapture {
  final List<SpanSnapshot> _captured = <SpanSnapshot>[];
  bool _shutdown = false;

  /// All captured span records, in export order.
  List<SpanSnapshot> get captured => List.unmodifiable(_captured);

  /// Names of every captured span, in export order.
  List<String> get spanNames => List.unmodifiable(_captured.map((r) => r.name));

  /// The first captured record named [name], or `null`.
  SpanSnapshot? byName(String name) {
    for (final record in _captured) {
      if (record.name == name) return record;
    }
    return null;
  }

  /// Whether a span named [name] was captured.
  bool hasSpan(String name) => byName(name) != null;

  /// Whether [shutdown] was called.
  bool get isShutdown => _shutdown;

  /// Forget everything captured so far (between scenarios).
  void reset() => _captured.clear();

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    if (_shutdown) return;
    for (final span in spans) {
      final attributes = <String, Object>{};
      for (final key in span.attributes.keys) {
        final value = span.attributes.get(key);
        if (value != null) attributes[key] = value;
      }
      _captured.add(
        SpanSnapshot(
          name: span.name,
          status: span.status.code,
          attributes: attributes,
        ),
      );
    }
  }

  @override
  void forceFlush() {
    // In-memory capture: nothing to flush.
  }

  @override
  void shutdown() {
    _shutdown = true;
  }
}
