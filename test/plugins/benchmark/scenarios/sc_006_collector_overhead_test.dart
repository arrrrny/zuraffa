// Success criterion SC-006 (specs/015-benchmark-plugin/spec.md):
// metric collection latency — custom metric collectors add < 1ms per
// collection point.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/metric_collector.dart';
import 'package:zuraffa/src/core/benchmark/standard_metrics.dart';

void main() {
  test('collector overhead under 1ms', () async {
    const collectionPoints = 2000;
    final context = MetricContext(
      scenarioId: 'overhead-scenario',
      scenarioName: 'Overhead',
      config: const {},
      elapsed: const Duration(milliseconds: 5),
      result: BenchmarkResult(
        scenarioId: 'overhead-scenario',
        scenarioName: 'Overhead',
        scenarioVersion: '1.0.0',
        status: BenchmarkStatus.passed,
        metrics: const {},
        thresholdViolations: const [],
        duration: const Duration(milliseconds: 5),
        timestamp: DateTime.now(),
      ),
      samples: List.generate(
        30,
        (i) => Duration(microseconds: 1000 + i * 10),
      ),
    );

    // A representative custom collector: derives metrics from the context.
    final collector = _CustomCollector();
    // Warm-up (both collectors' bodies run synchronously up to their
    // return, so the loop below times the real collection work).
    // ignore: unawaited_futures
    const StandardMetricCollector().collect(context);
    // ignore: unawaited_futures
    collector.collect(context);

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < collectionPoints; i++) {
      // ignore: unawaited_futures
      collector.collect(context);
    }
    stopwatch.stop();
    final customPerCall =
        stopwatch.elapsedMicroseconds / collectionPoints / 1000; // ms

    // The built-in standard collector must also stay under budget.
    final standard = const StandardMetricCollector();
    final standardStopwatch = Stopwatch()..start();
    for (var i = 0; i < collectionPoints; i++) {
      // ignore: unawaited_futures
      standard.collect(context);
    }
    standardStopwatch.stop();
    final standardPerCall =
        standardStopwatch.elapsedMicroseconds / collectionPoints / 1000;

    expect(customPerCall, lessThan(1.0),
        reason: 'custom collector took ${customPerCall}ms per collection '
            'point');
    expect(standardPerCall, lessThan(1.0),
        reason: 'standard collector took ${standardPerCall}ms per collection '
            'point');

    // The standard collector still produces the full metric set.
    final metrics = await const StandardMetricCollector().collect(context);
    for (final name in StandardMetrics.allNames) {
      expect(metrics.containsKey(name), isTrue);
    }
  });
}

class _CustomCollector implements MetricCollector {
  @override
  String get id => 'custom-overhead-collector';

  @override
  String get name => 'Custom Overhead Collector';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> beforeBenchmark(MetricContext context) async {}

  @override
  Future<Map<String, num>> collect(MetricContext context) async {
    // Representative work: iterate samples, compute derived metrics.
    var total = 0;
    for (final sample in context.samples) {
      total += sample.inMicroseconds;
    }
    return {
      'custom_mean_us': total / context.samples.length,
      'custom_count': context.samples.length,
    };
  }

  @override
  Future<void> finalize() async {}
}
