// Tests for lib/src/core/benchmark/benchmark_contract.dart — behaviors U1–U7
// of specs/015-benchmark-plugin/tdd/test-list.md.
//
// Threshold validation/evaluation and the BenchmarkScenario base class.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';

void main() {
  group('ThresholdConfig', () {
    test('rejects invalid operator', () {
      expect(
        () => ThresholdConfig.fromJson(const {
          'metric': 'latency_p99',
          'operator': 'between',
          'value': 100,
          'severity': 'error',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('between'),
          ),
        ),
      );
    });

    test('rejects invalid severity', () {
      expect(
        () => ThresholdConfig.fromJson(const {
          'metric': 'latency_p99',
          'operator': 'lte',
          'value': 100,
          'severity': 'fatal',
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('fatal'),
          ),
        ),
      );
    });

    test('lte boundary not violated', () {
      const config = ThresholdConfig(
        metric: 'latency_p99',
        operator: ThresholdOperator.lte,
        value: 100,
      );
      expect(config.isViolatedBy(100), isFalse);
      expect(config.isViolatedBy(99.9), isFalse);
      expect(config.isViolatedBy(100.1), isTrue);
    });

    test('lt boundary violated', () {
      const config = ThresholdConfig(
        metric: 'latency_p99',
        operator: ThresholdOperator.lt,
        value: 100,
      );
      expect(config.isViolatedBy(100), isTrue);
      expect(config.isViolatedBy(99.999), isFalse);
    });

    test('gte and gt operators evaluate correctly', () {
      const gte = ThresholdConfig(
        metric: 'throughput_ops_sec',
        operator: ThresholdOperator.gte,
        value: 1000,
      );
      expect(gte.isViolatedBy(1000), isFalse);
      expect(gte.isViolatedBy(999), isTrue);

      const gt = ThresholdConfig(
        metric: 'throughput_ops_sec',
        operator: ThresholdOperator.gt,
        value: 1000,
      );
      expect(gt.isViolatedBy(1000), isTrue);
      expect(gt.isViolatedBy(1001), isFalse);
    });

    test('json round trip', () {
      const config = ThresholdConfig(
        metric: 'memory_mb',
        operator: ThresholdOperator.lte,
        value: 512,
        severity: ThresholdSeverity.warn,
      );
      final restored = ThresholdConfig.fromJson(config.toJson());
      expect(restored.metric, 'memory_mb');
      expect(restored.operator, ThresholdOperator.lte);
      expect(restored.value, 512);
      expect(restored.severity, ThresholdSeverity.warn);
      expect(restored.expectation, 'memory_mb <= 512');
    });
  });

  group('BenchmarkScenario', () {
    test('validates scenario id', () {
      expect(
        ScenarioValidation.validateId('entity-crud-benchmark'),
        isEmpty,
      );
      expect(
        ScenarioValidation.validateId(''),
        isNotEmpty,
      );
      expect(
        ScenarioValidation.validateId('Entity Crud'),
        isNotEmpty,
      );
      expect(
        ScenarioValidation.validateId('snake_case'),
        isNotEmpty,
      );
    });

    test('rejects invalid version', () {
      expect(ScenarioValidation.validateVersion('1.2.3'), isEmpty);
      expect(ScenarioValidation.validateVersion('1.2.3-beta.1'), isEmpty);
      expect(ScenarioValidation.validateVersion('1.2'), isNotEmpty);
      expect(ScenarioValidation.validateVersion('v1.2.3'), isNotEmpty);
      expect(ScenarioValidation.validateVersion('latest'), isNotEmpty);
    });

    test('metadata defaults', () async {
      final scenario = _MinimalScenario();
      expect(scenario.description, '');
      expect(scenario.configSchema, isEmpty);
      expect(scenario.thresholds, isEmpty);
      expect(scenario.tags, isEmpty);
      // Lifecycle defaults are no-ops that complete.
      await scenario.setup();
      await scenario.teardown();
      expect(await scenario.collectMetrics(), isEmpty);
    });

    test('validate reports all metadata problems at once', () {
      final scenario = _InvalidScenario();
      final errors = ScenarioValidation.validate(scenario);
      expect(errors, contains(contains('id')));
      expect(errors, contains(contains('version')));
    });
  });
}

/// Smallest legal scenario: proves the base class carries usable defaults
/// (SC-001 ergonomics — a working scenario in a handful of lines).
class _MinimalScenario extends BenchmarkScenario {
  @override
  String get id => 'minimal-scenario';

  @override
  String get name => 'Minimal';

  @override
  String get version => '1.0.0';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async =>
      BenchmarkResult(
        scenarioId: id,
        scenarioName: name,
        scenarioVersion: version,
        status: BenchmarkStatus.passed,
        metrics: const {'ops': 1},
        thresholdViolations: const [],
        duration: Duration.zero,
        timestamp: DateTime.now(),
      );
}

/// Scenario with invalid metadata, for validation tests.
class _InvalidScenario extends BenchmarkScenario {
  @override
  String get id => 'Invalid ID';

  @override
  String get name => 'Invalid';

  @override
  String get version => 'not-semver';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async =>
      throw UnimplementedError();
}
