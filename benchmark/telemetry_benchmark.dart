import 'package:zuraffa/zuraffa.dart';

/// Benchmark verifying zero-cost overhead when telemetry is disabled.
///
/// Run with: `dart run benchmark/telemetry_benchmark.dart`
void main() {
  const iterations = 100000;

  print('=== Telemetry Mesh Zero-Cost Benchmark ===\n');

  // ── Baseline: raw function call ──
  final swBase = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final _ = _rawWork();
  }
  swBase.stop();
  print('Raw function call ($iterations): ${swBase.elapsedMicroseconds} µs');
  print('  → ${swBase.elapsedMicroseconds / iterations} µs per call\n');

  // ── Telemetry DISABLED: trace() overhead ──
  TelemetryMesh.instance.disable();
  final swDisabled = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    TelemetryMesh.instance.trace('noop', _rawWork);
  }
  swDisabled.stop();
  print(
    'TelemetryMesh.trace() DISABLED ($iterations): ${swDisabled.elapsedMicroseconds} µs',
  );
  print('  → ${swDisabled.elapsedMicroseconds / iterations} µs per call');
  print(
    '  → Overhead: ${((swDisabled.elapsedMicroseconds - swBase.elapsedMicroseconds) / swBase.elapsedMicroseconds * 100).toStringAsFixed(2)}%\n',
  );

  // ── Telemetry ENABLED: trace() with real spans ──
  TelemetryMesh.instance.enable(exporters: [_NullExporter()]);
  final swEnabled = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    TelemetryMesh.instance.trace('real', _rawWork);
  }
  swEnabled.stop();
  print(
    'TelemetryMesh.trace() ENABLED ($iterations): ${swEnabled.elapsedMicroseconds} µs',
  );
  print('  → ${swEnabled.elapsedMicroseconds / iterations} µs per call');
  print(
    '  → Overhead vs raw: ${((swEnabled.elapsedMicroseconds - swBase.elapsedMicroseconds) / swBase.elapsedMicroseconds * 100).toStringAsFixed(2)}%\n',
  );

  // ── Context current() read speed ──
  final swCtx = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final _ = ZuraffaContext.current;
  }
  swCtx.stop();
  print(
    'ZuraffaContext.current read ($iterations): ${swCtx.elapsedMicroseconds} µs',
  );
  print('  → ${swCtx.elapsedMicroseconds / iterations} µs per read (O(1))\n');

  // ── Context zone propagation speed ──
  const ctx = ZuraffaContext(traceId: 'bench');
  final swZone = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    ZuraffaContext.runWith(ctx, () {
      final _ = ZuraffaContext.current.traceId;
    });
  }
  swZone.stop();
  print(
    'Zone propagation + read ($iterations): ${swZone.elapsedMicroseconds} µs',
  );
  print('  → ${swZone.elapsedMicroseconds / iterations} µs per propagation\n');

  TelemetryMesh.instance.disable();
  print('=== End Benchmark ===');
}

int _rawWork() => 42;

class _NullExporter implements TelemetryExporter {
  @override
  void export(ZuraffaTrace trace) {}
}
