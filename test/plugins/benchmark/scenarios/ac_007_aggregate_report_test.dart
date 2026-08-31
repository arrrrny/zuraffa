@Tags(['slow'])
library;

// Acceptance test AC-7 (specs/015-benchmark-plugin/spec.md US3):
// running multiple benchmarks in sequence produces an aggregate report with
// per-benchmark results and overall pass/fail status.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('aggregate report has per-benchmark and overall status', () async {
    final runner = DefaultBenchmarkRunner();
    final suite = await runner.run([
      RecordingScenario('report-passing-a'),
      RecordingScenario('report-passing-b'),
      ThrowingScenario('report-broken', throwIn: LifecycleStage.run),
    ]);

    // Per-benchmark results in order.
    expect(suite.results, hasLength(3));
    expect(suite.results[0].scenarioId, 'report-passing-a');
    expect(suite.results[0].status, BenchmarkStatus.passed);
    expect(suite.results[2].status, BenchmarkStatus.error);

    // Overall status reflects the worst outcome.
    expect(suite.overallStatus, BenchmarkStatus.error);
    expect(suite.summary['total'], 3);
    expect(suite.summary['passed'], 2);
    expect(suite.summary['error'], 1);

    // The aggregate report is machine-serializable (CI shape, FR-008).
    final json = suite.toJson();
    expect(json['overallStatus'], 'error');
    expect((json['results'] as List<dynamic>), hasLength(3));

    // A clean suite reports passed overall.
    final clean = await runner.run([
      RecordingScenario('report-clean-a'),
      RecordingScenario('report-clean-b'),
    ]);
    expect(clean.overallStatus, BenchmarkStatus.passed);
    expect(clean.summary['passed'], 2);
  });
}
