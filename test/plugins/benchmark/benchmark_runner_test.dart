@Tags(['slow'])
// Tests for lib/src/core/benchmark/benchmark_runner.dart — behaviors
// U25–U38 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import 'helpers/fake_collectors.dart';
import 'helpers/fake_scenarios.dart';

void main() {
  group('DefaultBenchmarkRunner.runSingle', () {
    test('lifecycle order', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = RecordingScenario('lifecycle-scenario');

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.passed);
      expect(scenario.calls, ['setup', 'run', 'collectMetrics', 'teardown']);
      // Custom metrics from collectMetrics are merged into the result.
      expect(result.metrics, containsPair('lifecycle-scenario_custom', 7));
    });

    test('config merge', () async {
      final runner = DefaultBenchmarkRunner(
        config: const BenchmarkRunnerConfig(
          globalConfig: {'iterations': 2, 'shared': 'from-global'},
        ),
      );
      final scenario = RecordingScenario('config-scenario');

      await runner.runSingle(scenario, config: const {'iterations': 5});

      expect(scenario.lastConfig, containsPair('iterations', 5));
      expect(scenario.lastConfig, containsPair('shared', 'from-global'));
    });

    test('setup error skips run and teardown', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = ThrowingScenario(
        'setup-fail',
        throwIn: LifecycleStage.setup,
      );

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.error);
      expect(result.metadata['error'], contains('setup exploded'));
      expect(scenario.calls, ['setup']); // run and teardown skipped
    });

    test('run error captured, teardown called', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = ThrowingScenario(
        'run-fail',
        throwIn: LifecycleStage.run,
      );

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.error);
      expect(result.metadata['error'], contains('run exploded'));
      expect(scenario.calls, ['setup', 'run', 'teardown']);
    });

    test('collectMetrics error is captured, run still succeeds', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = ThrowingScenario(
        'collect-fail',
        throwIn: LifecycleStage.collectMetrics,
      );

      final result = await runner.runSingle(scenario);

      // The benchmark itself ran fine; the collector stage failure is a
      // warning, not an error status.
      expect(result.status, BenchmarkStatus.passed);
      expect(
        result.metadata['warnings'],
        anyElement(contains('collectMetrics exploded')),
      );
      expect(scenario.calls, ['setup', 'run', 'collectMetrics', 'teardown']);
    });

    test('error threshold fails', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = FixedMetricScenario(
        'threshold-fail',
        const {'latency_p99': 250},
        thresholds: const {
          'latency_p99': ThresholdConfig(
            metric: 'latency_p99',
            operator: ThresholdOperator.lte,
            value: 100,
            severity: ThresholdSeverity.error,
          ),
        },
      );

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.failed);
      expect(result.thresholdViolations, hasLength(1));
      expect(result.thresholdViolations.first.metric, 'latency_p99');
      expect(result.thresholdViolations.first.actual, 250);
      expect(result.thresholdViolations.first.message, contains('latency_p99'));
    });

    test('warn violation stays passed', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = FixedMetricScenario(
        'threshold-warn',
        const {'memory_mb': 600},
        thresholds: const {
          'memory_mb': ThresholdConfig(
            metric: 'memory_mb',
            operator: ThresholdOperator.lte,
            value: 512,
            severity: ThresholdSeverity.warn,
          ),
        },
      );

      final result = await runner.runSingle(scenario);

      expect(result.status, BenchmarkStatus.passed);
      expect(result.thresholdViolations, hasLength(1));
      expect(result.thresholdViolations.first.severity, ThresholdSeverity.warn);
    });

    test('metadata records config', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = RecordingScenario('metadata-scenario');

      final result = await runner.runSingle(
        scenario,
        config: const {'iterations': 3},
      );

      expect(result.metadata['config'], containsPair('iterations', 3));
      expect(result.metadata['iterations'], 3);
      expect(result.metadata['sampleCount'], 3);
      expect(result.gitCommit, isNotEmpty);
    });

    test('timeout fails gracefully', () async {
      final runner = DefaultBenchmarkRunner(
        config: const BenchmarkRunnerConfig(
          timeout: Duration(milliseconds: 80),
        ),
      );
      final slow = SlowScenario('slow-scenario', const Duration(seconds: 5));
      final fast = RecordingScenario('fast-scenario');

      final slowResult = await runner.runSingle(slow);
      expect(slowResult.status, BenchmarkStatus.failed);
      expect(
        slowResult.thresholdViolations.map((v) => v.metric),
        contains('timeout'),
      );

      // The runner keeps working for other scenarios.
      final fastResult = await runner.runSingle(fast);
      expect(fastResult.status, BenchmarkStatus.passed);
      expect(fast.calls, contains('run'));
    });
  });

  group('DefaultBenchmarkRunner.run', () {
    test('run executes all', () async {
      final runner = DefaultBenchmarkRunner();
      final scenarios = [
        RecordingScenario('suite-a'),
        RecordingScenario('suite-b'),
        RecordingScenario('suite-c'),
      ];

      final suite = await runner.run(scenarios);

      expect(suite.results, hasLength(3));
      expect(
        suite.results.map((r) => r.scenarioId),
        containsAll(['suite-a', 'suite-b', 'suite-c']),
      );
      expect(suite.overallStatus, BenchmarkStatus.passed);
      expect(suite.summary['total'], 3);
      expect(suite.summary['passed'], 3);
    });

    test('continues after error', () async {
      final runner = DefaultBenchmarkRunner();
      final scenarios = [
        RecordingScenario('healthy-a'),
        ThrowingScenario('broken', throwIn: LifecycleStage.run),
        RecordingScenario('healthy-b'),
      ];

      final suite = await runner.run(scenarios);

      expect(suite.results, hasLength(3));
      final broken = suite.results.firstWhere((r) => r.scenarioId == 'broken');
      expect(broken.status, BenchmarkStatus.error);
      // The scenario after the failure still ran.
      final after = suite.results.firstWhere(
        (r) => r.scenarioId == 'healthy-b',
      );
      expect(after.status, BenchmarkStatus.passed);
      expect(suite.overallStatus, BenchmarkStatus.error);
    });

    test('collector lifecycle hooks', () async {
      final collector = RecordingCollector();
      final runner = DefaultBenchmarkRunner(collectors: [collector]);
      final scenarios = [
        RecordingScenario('hook-a'),
        RecordingScenario('hook-b'),
      ];

      await runner.run(scenarios);

      expect(collector.calls, [
        'initialize',
        'beforeBenchmark:hook-a',
        'collect:hook-a',
        'beforeBenchmark:hook-b',
        'collect:hook-b',
        'finalize',
      ]);
      // Collector metrics are merged into each result.
      final suite = await runner.run(scenarios);
      for (final result in suite.results) {
        expect(result.metrics, containsPair('custom_metric', 123));
      }
    });

    test('concurrent run', () async {
      final runner = DefaultBenchmarkRunner();
      final scenarios = List.generate(
        12,
        (i) => RecordingScenario('concurrent-$i'),
      );

      final suite = await runner.run(scenarios, concurrency: 4);

      expect(suite.results, hasLength(12));
      expect(suite.overallStatus, BenchmarkStatus.passed);
      // Every scenario went through its full lifecycle exactly once.
      for (final scenario in scenarios) {
        expect(scenario.calls, ['setup', 'run', 'collectMetrics', 'teardown']);
      }
    });
  });

  group('DefaultBenchmarkRunner.dryRun', () {
    test('dry run validates only', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = SchemaScenario('schema-scenario');

      final result = await runner.dryRun(
        scenario,
        config: const {'entityCount': 10, 'label': 'x'},
      );

      expect(result.valid, isTrue);
      expect(result.errors, isEmpty);
      // Nothing executed.
      expect(scenario.calls, isEmpty);
    });

    test('dry run rejects bad config', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = SchemaScenario('schema-scenario');

      // Missing required property.
      final missing = await runner.dryRun(
        scenario,
        config: const {'label': 'x'},
      );
      expect(missing.valid, isFalse);
      expect(missing.errors.join('\n'), contains('entityCount'));

      // Wrong type.
      final wrongType = await runner.dryRun(
        scenario,
        config: const {'entityCount': 'not-an-int'},
      );
      expect(wrongType.valid, isFalse);
      expect(wrongType.errors.join('\n'), contains('integer'));

      // Below minimum.
      final tooSmall = await runner.dryRun(
        scenario,
        config: const {'entityCount': 0},
      );
      expect(tooSmall.valid, isFalse);
      expect(tooSmall.errors.join('\n'), contains('minimum'));

      expect(scenario.calls, isEmpty);
    });

    test('dry run rejects invalid scenario metadata', () async {
      final runner = DefaultBenchmarkRunner();
      final scenario = ThrowingScenario('Bad ID');

      final result = await runner.dryRun(scenario);
      expect(result.valid, isFalse);
      expect(result.errors.join('\n'), contains('kebab-case'));
    });
  });

  test('registerMetricCollector adds a collector to a live runner', () async {
    final collector = RecordingCollector();
    final runner = DefaultBenchmarkRunner();
    runner.registerMetricCollector(collector);

    final result = await runner.runSingle(RecordingScenario('late-collector'));

    expect(result.metrics, containsPair('custom_metric', 123));
    expect(collector.calls, contains('collect:late-collector'));
  });
}
