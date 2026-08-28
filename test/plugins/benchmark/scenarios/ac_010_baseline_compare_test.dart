// Acceptance test AC-10 (specs/015-benchmark-plugin/spec.md US5):
// comparing a result set against a baseline yields per-metric percentage
// changes with regression/improvement flags.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/baseline_store.dart';

void main() {
  test('comparison reports percent changes', () {
    final baseline = Baseline(
      scenarioId: 'trend-scenario',
      scenarioVersion: '1.0.0',
      label: 'v1.0-release',
      metrics: const {
        'latency_p50': 40,
        'latency_p99': 100,
        'throughput_ops_sec': 1000,
        'memory_mb': 200,
      },
      timestamp: DateTime.utc(2026, 8, 1),
    );

    final current = const <String, num>{
      'latency_p50': 20, // -50%: improvement (lower is better)
      'latency_p99': 105, // +5%: stable within 10% tolerance
      'throughput_ops_sec': 1500, // +50%: improvement (higher is better)
      'memory_mb': 260, // +30%: regression beyond tolerance
    };

    final comparison = compareBaselines(
      baseline,
      current,
      tolerancePercent: 10,
    );

    expect(comparison.scenarioId, 'trend-scenario');
    expect(comparison.changes, hasLength(4));

    // Per-metric percentage changes are exact.
    final latency = comparison.changes['latency_p50']!;
    expect(latency.percentChange, closeTo(-50, 1e-9));
    expect(latency.direction, MetricDirection.improved);

    final p99 = comparison.changes['latency_p99']!;
    expect(p99.percentChange, closeTo(5, 1e-9));
    expect(p99.direction, MetricDirection.stable);

    final throughput = comparison.changes['throughput_ops_sec']!;
    expect(throughput.percentChange, closeTo(50, 1e-9));
    expect(throughput.direction, MetricDirection.improved);

    final memory = comparison.changes['memory_mb']!;
    expect(memory.percentChange, closeTo(30, 1e-9));
    expect(memory.direction, MetricDirection.regressed);
    expect(memory.isRegression, isTrue);

    // Overall verdict reflects the worst direction.
    expect(comparison.overallStatus, ComparisonStatus.regressed);
  });
}
