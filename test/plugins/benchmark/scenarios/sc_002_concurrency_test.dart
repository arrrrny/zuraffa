// Success criterion SC-002 (specs/015-benchmark-plugin/spec.md):
// the benchmark runner can execute 100+ concurrent benchmark scenarios
// without resource contention issues.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('100+ scenarios complete', () async {
    const count = 120;
    final scenarios = List.generate(
      count,
      (i) => RecordingScenario('concurrent-scenario-$i'),
    );

    final runner = DefaultBenchmarkRunner();
    final stopwatch = Stopwatch()..start();
    final suite = await runner.run(scenarios, concurrency: 8);
    stopwatch.stop();

    // Every scenario completed with a result — no contention failures.
    expect(suite.results, hasLength(count));
    expect(suite.overallStatus, BenchmarkStatus.passed);
    for (final result in suite.results) {
      expect(result.status, BenchmarkStatus.passed,
          reason: 'scenario ${result.scenarioId} did not pass');
    }

    // Every scenario ran its full lifecycle exactly once.
    for (final scenario in scenarios) {
      expect(scenario.calls, ['setup', 'run', 'collectMetrics', 'teardown']);
    }

    // The suite is an aggregate over unique scenario ids.
    expect(suite.results.map((r) => r.scenarioId).toSet(), hasLength(count));
  });
}
