@Tags(['slow'])
// Tests for lib/src/core/benchmark/metric_collector.dart — behaviors
// U39–U43 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import 'helpers/fake_collectors.dart';
import 'helpers/fake_scenarios.dart';

void main() {
  group('StandardMetricCollector', () {
    test('latency percentiles produced', () async {
      final runner = DefaultBenchmarkRunner();
      final result = await runner.runSingle(
        RecordingScenario('latency-scenario'),
        config: const {'iterations': 3},
      );

      // Three timed iterations of a trivial run(): latency values must be
      // present and non-negative.
      expect(result.metrics.containsKey('latency_p50'), isTrue);
      expect(result.metrics.containsKey('latency_p95'), isTrue);
      expect(result.metrics.containsKey('latency_p99'), isTrue);
      for (final name in ['latency_p50', 'latency_p95', 'latency_p99']) {
        expect(result.metrics[name], greaterThanOrEqualTo(0));
      }
      // Percentile ordering holds for any sample set.
      expect(
        result.metrics['latency_p50']!,
        lessThanOrEqualTo(result.metrics['latency_p99']!),
      );
    });

    test('throughput produced', () async {
      final runner = DefaultBenchmarkRunner();
      final result = await runner.runSingle(
        RecordingScenario('throughput-scenario'),
        config: const {'iterations': 5},
      );

      expect(result.metrics.containsKey('throughput_ops_sec'), isTrue);
      expect(result.metrics['throughput_ops_sec'], greaterThan(0));
    });

    test('memory and cpu produced', () async {
      final runner = DefaultBenchmarkRunner();
      final result = await runner.runSingle(
        RecordingScenario('resource-scenario'),
      );

      expect(result.metrics.containsKey('memory_mb'), isTrue);
      expect(result.metrics.containsKey('cpu_percent'), isTrue);
      expect(result.metrics['memory_mb'], greaterThanOrEqualTo(0));
      expect(result.metrics['cpu_percent'], greaterThanOrEqualTo(0));
      expect(result.metrics['cpu_percent'], lessThanOrEqualTo(100));
    });

    test('throwing collector isolated', () async {
      final bad = RecordingCollector(throwInCollect: true);
      final runner = DefaultBenchmarkRunner(collectors: [bad]);
      final result = await runner.runSingle(
        RecordingScenario('collector-failure-scenario'),
      );

      // The benchmark still passes; the collector failure is a warning.
      expect(result.status, BenchmarkStatus.passed);
      expect(result.metrics.containsKey('custom_metric'), isFalse);
      expect(
        result.metadata['warnings'],
        anyElement(contains('collector exploded')),
      );

      // And the suite continues with more scenarios.
      final suite = await runner.run([
        RecordingScenario('after-failure-a'),
        RecordingScenario('after-failure-b'),
      ]);
      expect(suite.overallStatus, BenchmarkStatus.passed);
      expect(suite.results, hasLength(2));
    });

    test('context carries scenario data', () async {
      final collector = RecordingCollector();
      final runner = DefaultBenchmarkRunner(collectors: [collector]);
      final scenario = RecordingScenario('context-scenario');

      await runner.runSingle(scenario, config: const {'iterations': 2});

      final context = collector.contexts['context-scenario'];
      expect(context, isNotNull);
      expect(context!.scenarioId, 'context-scenario');
      expect(context.scenarioName, 'Scenario for context-scenario');
      expect(context.config, containsPair('iterations', 2));
      expect(context.result, isNotNull);
      expect(context.samples, isNotEmpty);
    });
  });
}
