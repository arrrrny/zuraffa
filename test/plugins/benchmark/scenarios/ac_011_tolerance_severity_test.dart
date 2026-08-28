// Acceptance test AC-11 (specs/015-benchmark-plugin/spec.md US5):
// a metric regressed beyond the configured tolerance is flagged with
// severity.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/baseline_store.dart';

void main() {
  test('regression beyond tolerance flagged with severity', () {
    final baseline = Baseline(
      scenarioId: 'severity-scenario',
      scenarioVersion: '1.0.0',
      label: 'v1.0-release',
      metrics: const {
        'latency_p99': 100,
        'memory_mb': 100,
      },
      timestamp: DateTime.utc(2026, 8, 1),
    );

    // +15% (just beyond 10% tolerance) -> warn severity.
    final borderline = compareBaselines(
      baseline,
      const {'latency_p99': 115, 'memory_mb': 100},
      tolerancePercent: 10,
    );
    final borderlineChange = borderline.changes['latency_p99']!;
    expect(borderlineChange.isRegression, isTrue);
    expect(borderlineChange.severity, 'warn');

    // +40% (beyond 2x tolerance) -> error severity.
    final severe = compareBaselines(
      baseline,
      const {'latency_p99': 140, 'memory_mb': 100},
      tolerancePercent: 10,
    );
    final severeChange = severe.changes['latency_p99']!;
    expect(severeChange.isRegression, isTrue);
    expect(severeChange.severity, 'error');

    // Tolerance is configurable: the same +15% regression is stable under
    // a 20% tolerance.
    final relaxed = compareBaselines(
      baseline,
      const {'latency_p99': 115, 'memory_mb': 100},
      tolerancePercent: 20,
    );
    expect(relaxed.changes['latency_p99']!.isRegression, isFalse);
    expect(relaxed.overallStatus, ComparisonStatus.stable);
  });
}
