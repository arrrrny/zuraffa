@Tags(['slow'])
// Acceptance test AC-5 (specs/015-benchmark-plugin/spec.md US3):
// a runner-executed scenario produces latency p50/p95/p99, throughput,
// memory and CPU metrics.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';
import 'package:zuraffa/src/core/benchmark/standard_metrics.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('standard metrics produced', () async {
    final runner = DefaultBenchmarkRunner();
    final result = await runner.runSingle(
      RecordingScenario('standard-metrics-scenario'),
      config: const {'iterations': 10},
    );

    for (final name in StandardMetrics.allNames) {
      expect(
        result.metrics.containsKey(name),
        isTrue,
        reason: 'metric $name missing from ${result.metrics.keys}',
      );
      expect(result.metrics[name], greaterThanOrEqualTo(0));
    }
  });
}
