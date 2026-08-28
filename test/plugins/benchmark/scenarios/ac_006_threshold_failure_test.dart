// Acceptance test AC-6 (specs/015-benchmark-plugin/spec.md US3):
// a benchmark exceeding a configured threshold is marked failed with the
// specific violating metric named in the result.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

void main() {
  test('threshold violation fails run', () async {
    final runner = DefaultBenchmarkRunner();
    final result = await runner.runSingle(
      _ThresholdedScenario(latencyP99: 250),
    );

    expect(result.status, BenchmarkStatus.failed);
    expect(result.thresholdViolations, isNotEmpty);
    final violation = result.thresholdViolations.first;
    expect(violation.metric, 'latency_p99');
    expect(violation.actual, 250);
    expect(violation.expected, contains('latency_p99'));

    // A conforming value passes the same gate.
    final passing = await runner.runSingle(
      _ThresholdedScenario(latencyP99: 80),
    );
    expect(passing.status, BenchmarkStatus.passed);
    expect(passing.thresholdViolations, isEmpty);
  });
}

class _ThresholdedScenario extends BenchmarkScenario {
  _ThresholdedScenario({required this.latencyP99});

  final num latencyP99;

  @override
  String get id => 'thresholded-scenario';

  @override
  String get name => 'Thresholded Scenario';

  @override
  String get version => '1.0.0';

  @override
  Map<String, ThresholdConfig> get thresholds => const {
        'latency_p99': ThresholdConfig(
          metric: 'latency_p99',
          operator: ThresholdOperator.lte,
          value: 100,
          severity: ThresholdSeverity.error,
        ),
      };

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async =>
      BenchmarkResult(
        scenarioId: id,
        scenarioName: name,
        scenarioVersion: version,
        status: BenchmarkStatus.passed,
        metrics: {'latency_p99': latencyP99},
        thresholdViolations: const [],
        duration: const Duration(milliseconds: 1),
        timestamp: DateTime.now(),
      );
}
