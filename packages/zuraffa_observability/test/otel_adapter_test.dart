// Spec 1653-trim-heavy-deps (issue #1661): the OtelAdapter tests moved
// with the adapter from the core simulation suite to the observability
// companion (the vendor-typed exporter lives here; core consumes the
// light SimulationSpanCapture seam).
library;

import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:test/test.dart';
import 'package:zuraffa_observability/zuraffa_observability.dart';

void main() {
  group('OtelAdapter (capture-and-assert exporter)', () {
    test('captures spans produced through the real SDK pipeline', () async {
      final otel = OtelAdapter();
      final provider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(otel)],
      );
      final tracer = provider.getTracer('simulation-test');
      final span = tracer.startSpan(
        'usecase.PlaceOrder',
        attributes: [otel_api.Attribute.fromString('order.id', 'o-42')],
      );
      span.end();

      // Give the SimpleSpanProcessor a microtask to export.
      await Future<void>.delayed(Duration.zero);

      expect(otel.spanNames, contains('usecase.PlaceOrder'));
      final record = otel.byName('usecase.PlaceOrder');
      expect(record, isNotNull);
      expect(record!.attributes['order.id'], 'o-42');
      expect(otel.hasSpan('usecase.PlaceOrder'), isTrue);
      expect(otel.hasSpan('usecase.NeverRan'), isFalse);
    });

    test('capture-and-assert: ended spans report their status', () async {
      final otel = OtelAdapter();
      final provider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(otel)],
      );
      final tracer = provider.getTracer('simulation-test');
      final ok = tracer.startSpan('usecase.Healthy')..end();
      expect(ok, isNotNull);
      final failing = tracer.startSpan('usecase.Broken');
      failing.setStatus(otel_api.StatusCode.error, 'boom');
      failing.end();
      await Future<void>.delayed(Duration.zero);

      final healthy = otel.byName('usecase.Healthy');
      final broken = otel.byName('usecase.Broken');
      expect(healthy, isNotNull);
      expect(broken, isNotNull);
      expect(broken!.status, otel_api.StatusCode.error);
    });

    test('implements the production SpanExporter interface', () {
      final otel = OtelAdapter();
      // Same production interface the OTLP collector exporter implements.
      expect(otel, isA<otel_sdk.SpanExporter>());
      otel.forceFlush();
      otel.shutdown();
      expect(otel.isShutdown, isTrue);
    });
  });
}
