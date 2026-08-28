// Success criterion SC-004 (specs/015-benchmark-plugin/spec.md):
// CI/CD integration — running the full benchmark suite completes in under
// 5 minutes for a typical Zuraffa app with 20 scenarios.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('20-scenario suite under 5 min', () async {
    // A typical app suite: 20 scenarios, each with a realistic (small)
    // workload of 10 measured iterations.
    final scenarios = List.generate(
      20,
      (i) => RecordingScenario('ci-scenario-$i', metrics: const {'ops': 10}),
    );

    final runner = DefaultBenchmarkRunner(
      config: const BenchmarkRunnerConfig(
        globalConfig: {'iterations': 10},
      ),
    );

    final wallClock = Stopwatch()..start();
    final suite = await runner.run(scenarios);
    wallClock.stop();

    // The suite completes with full per-benchmark results.
    expect(suite.results, hasLength(20));
    expect(suite.overallStatus, BenchmarkStatus.passed);
    for (final result in suite.results) {
      expect(result.metadata['sampleCount'], 10);
    }

    // SC-004: the whole suite finishes well within the 5-minute budget.
    expect(wallClock.elapsed, lessThan(const Duration(minutes: 5)));
    // Sanity: this suite shape is far smaller than the budget.
    expect(wallClock.elapsed, lessThan(const Duration(minutes: 1)));
  });
}
