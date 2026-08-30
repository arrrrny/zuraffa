@Tags(['slow'])

// Tests for lib/src/core/benchmark/isolate_benchmark_runner.dart —
// behaviors U44–U46 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/isolate_benchmark_runner.dart';

import 'helpers/fake_scenarios.dart';

void main() {
  group('IsolateBenchmarkRunner', () {
    test('result returns from isolate', () async {
      final runner = IsolateBenchmarkRunner();
      final scenario = RecordingScenario('isolate-scenario');

      final result = await runner.runSingle(
        scenario,
        config: const {'iterations': 2, 'shared': 'from-global'},
      );

      expect(result.scenarioId, 'isolate-scenario');
      expect(result.status, BenchmarkStatus.passed);
      // Custom metrics from collectMetrics survive the isolate boundary.
      expect(result.metrics, containsPair('isolate-scenario_custom', 7));
      // Standard metrics are produced.
      expect(result.metrics.containsKey('latency_p99'), isTrue);
      // The scenario inside the isolate saw the merged config.
      expect(result.metadata['config'], containsPair('iterations', 2));
    });

    test('isolate crash contained', () async {
      final runner = IsolateBenchmarkRunner();
      final scenario = ThrowingScenario(
        'isolate-crash',
        throwIn: LifecycleStage.run,
      );

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.error);
      expect(result.metadata['error'], contains('run exploded'));

      // The host runner still works for the next scenario.
      final healthy = await runner.runSingle(RecordingScenario('after-crash'));
      expect(healthy.status, BenchmarkStatus.passed);
    });

    test('isolation metadata recorded', () async {
      final runner = IsolateBenchmarkRunner();
      final result = await runner.runSingle(
        RecordingScenario('metadata-isolate-scenario'),
      );

      expect(result.metadata['isolated'], isTrue);
    });

    test('suite run aggregates across isolate executions', () async {
      final runner = IsolateBenchmarkRunner();
      final suite = await runner.run([
        RecordingScenario('suite-iso-a'),
        RecordingScenario('suite-iso-b'),
      ]);

      expect(suite.results, hasLength(2));
      expect(suite.overallStatus, BenchmarkStatus.passed);
      for (final result in suite.results) {
        expect(result.metadata['isolated'], isTrue);
      }
    });
  });
}
