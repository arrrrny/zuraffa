// Acceptance test AC-9 (specs/015-benchmark-plugin/spec.md US4):
// a metric collector that throws is logged and does not fail the benchmark
// or the suite.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import '../helpers/fake_collectors.dart';
import '../helpers/fake_scenarios.dart';

void main() {
  test('throwing collector is isolated', () async {
    final bad = RecordingCollector(
      id: 'exploding-collector',
      throwInCollect: true,
    );
    final good = RecordingCollector(id: 'healthy-collector');
    final runner = DefaultBenchmarkRunner(collectors: [bad, good]);

    final result = await runner.runSingle(
      RecordingScenario('collector-failure-suite-scenario'),
    );

    // The benchmark itself still passes.
    expect(result.status, BenchmarkStatus.passed);
    // The failing collector's metrics are absent, the healthy one's present.
    expect(result.metrics.containsKey('custom_metric'), isTrue);
    // The failure is recorded as a warning.
    expect(
      result.metadata['warnings'],
      anyElement(contains('exploding-collector')),
    );

    // The suite continues with more benchmarks — none failed.
    final suite = await runner.run([
      RecordingScenario('post-failure-a'),
      RecordingScenario('post-failure-b'),
      RecordingScenario('post-failure-c'),
    ]);
    expect(suite.results, hasLength(3));
    expect(suite.overallStatus, BenchmarkStatus.passed);
    for (final suiteResult in suite.results) {
      expect(suiteResult.status, BenchmarkStatus.passed);
    }
  });
}
