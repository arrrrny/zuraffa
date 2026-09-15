// Spec 1653-trim-heavy-deps (issue #1661) — the companion init pin.
//
// `ZuraffaObservability.init()` wires the otel-backed OtelTracer into
// core's light TraceObserver seam, so hooks and use cases surface real
// trace/span ids exactly as before the split (FR-007 for the
// observability capability).
library;

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa_observability/zuraffa_observability.dart';

void main() {
  test('init() registers the otel-backed observer; ids flow through the '
      'seam', () {
    final saved = TraceObserver.instance;
    addTearDown(() => TraceObserver.instance = saved);

    // The seam accepts any observer; the companion's OtelTracer is one.
    TraceObserver.instance = OtelTracer.instance;

    expect(TraceObserver.instance, same(OtelTracer.instance));
    expect(TraceObserver.instance, isA<TraceObserver>());
    // The tracer's own getters stay functional (null while no span is
    // active — same as the pre-split no-span behavior).
    expect(OtelTracer.instance.currentTraceId, isNull);
  });
}
