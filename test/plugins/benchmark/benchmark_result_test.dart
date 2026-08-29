// Tests for lib/src/core/benchmark/benchmark_result.dart — behaviors U8–U12
// of specs/015-benchmark-plugin/tdd/test-list.md.
//
// Pure value types: JSON round-trips, status validation, suite aggregation.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';

void main() {
  group('BenchmarkResult', () {
    test('json round trip', () {
      final result = BenchmarkResult(
        scenarioId: 'entity-crud-benchmark',
        scenarioName: 'Entity CRUD Operations',
        scenarioVersion: '1.2.0',
        status: BenchmarkStatus.failed,
        metrics: const {
          'latency_p50': 12.5,
          'latency_p95': 30.25,
          'latency_p99': 41.0,
          'throughput_ops_sec': 8000,
          'memory_mb': 128,
          'cpu_percent': 74.5,
          'custom_db_queries': 42,
        },
        thresholdViolations: [
          ThresholdViolation(
            metric: 'latency_p99',
            expected: 'latency_p99 lte 40',
            actual: 41,
            severity: ThresholdSeverity.error,
            message: 'latency_p99 was 41, expected <= 40',
          ),
        ],
        duration: const Duration(milliseconds: 1500),
        timestamp: DateTime.utc(2026, 8, 28, 12, 0, 0),
        gitCommit: 'ab12cd34',
        metadata: const {
          'config': {'iterations': 100},
          'isolate': true,
        },
      );

      final json = result.toJson();
      final restored = BenchmarkResult.fromJson(json);

      expect(restored.scenarioId, result.scenarioId);
      expect(restored.scenarioName, result.scenarioName);
      expect(restored.scenarioVersion, result.scenarioVersion);
      expect(restored.status, BenchmarkStatus.failed);
      expect(restored.metrics, result.metrics);
      expect(restored.thresholdViolations, hasLength(1));
      expect(restored.thresholdViolations.first.metric, 'latency_p99');
      expect(restored.thresholdViolations.first.expected, 'latency_p99 lte 40');
      expect(restored.thresholdViolations.first.actual, 41);
      expect(
        restored.thresholdViolations.first.severity,
        ThresholdSeverity.error,
      );
      expect(restored.duration, const Duration(milliseconds: 1500));
      expect(restored.timestamp, result.timestamp);
      expect(restored.gitCommit, 'ab12cd34');
      expect(restored.metadata, result.metadata);

      // Must also be valid JSON-encodable through dart:convert.
      final encoded = jsonEncode(result.toJson());
      expect(encoded, isNotEmpty);
      expect(
        BenchmarkResult.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        ).status,
        BenchmarkStatus.failed,
      );
    });

    test('rejects invalid status', () {
      expect(
        () => BenchmarkResult.fromJson({
          'scenarioId': 's',
          'scenarioName': 'S',
          'scenarioVersion': '1.0.0',
          'status': 'exploded',
          'metrics': <String, num>{},
          'thresholdViolations': <Map<String, dynamic>>[],
          'durationMs': 0,
          'timestamp': DateTime.utc(2026).toIso8601String(),
          'gitCommit': 'unknown',
          'metadata': <String, dynamic>{},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('exploded'),
          ),
        ),
      );
    });
  });

  group('ThresholdViolation', () {
    test('violation round trip', () {
      final violation = ThresholdViolation(
        metric: 'throughput_ops_sec',
        expected: 'throughput_ops_sec gte 1000',
        actual: 950,
        severity: ThresholdSeverity.warn,
        message: 'throughput_ops_sec was 950, expected >= 1000',
      );

      final restored = ThresholdViolation.fromJson(violation.toJson());
      expect(restored.metric, 'throughput_ops_sec');
      expect(restored.expected, 'throughput_ops_sec gte 1000');
      expect(restored.actual, 950);
      expect(restored.severity, ThresholdSeverity.warn);
      expect(restored.message, contains('950'));
    });
  });

  group('BenchmarkSuiteResult', () {
    BenchmarkResult resultOf(BenchmarkStatus status) => BenchmarkResult(
      scenarioId: 's-${status.name}',
      scenarioName: 'S ${status.name}',
      scenarioVersion: '1.0.0',
      status: status,
      metrics: const {},
      thresholdViolations: const [],
      duration: const Duration(milliseconds: 10),
      timestamp: DateTime.utc(2026, 8, 28),
      gitCommit: 'unknown',
      metadata: const {},
    );

    test('overall failed when any failed', () {
      final suite = BenchmarkSuiteResult(
        results: [
          resultOf(BenchmarkStatus.passed),
          resultOf(BenchmarkStatus.failed),
        ],
        totalDuration: const Duration(milliseconds: 20),
        startedAt: DateTime.utc(2026, 8, 28, 12),
        completedAt: DateTime.utc(2026, 8, 28, 12, 0, 1),
      );
      expect(suite.overallStatus, BenchmarkStatus.failed);
    });

    test('overall error when any errored', () {
      final suite = BenchmarkSuiteResult(
        results: [resultOf(BenchmarkStatus.error)],
        totalDuration: const Duration(milliseconds: 20),
        startedAt: DateTime.utc(2026, 8, 28, 12),
        completedAt: DateTime.utc(2026, 8, 28, 12, 0, 1),
      );
      expect(suite.overallStatus, BenchmarkStatus.error);
    });

    test('summary counts statuses', () {
      final suite = BenchmarkSuiteResult(
        results: [
          resultOf(BenchmarkStatus.passed),
          resultOf(BenchmarkStatus.passed),
          resultOf(BenchmarkStatus.failed),
          resultOf(BenchmarkStatus.error),
          resultOf(BenchmarkStatus.skipped),
        ],
        totalDuration: const Duration(milliseconds: 50),
        startedAt: DateTime.utc(2026, 8, 28, 12),
        completedAt: DateTime.utc(2026, 8, 28, 12, 0, 1),
      );

      expect(suite.summary['total'], 5);
      expect(suite.summary['passed'], 2);
      expect(suite.summary['failed'], 1);
      expect(suite.summary['error'], 1);
      expect(suite.summary['skipped'], 1);
      expect(suite.summary['totalDurationMs'], 50);

      // Suite itself round-trips through JSON.
      final restored = BenchmarkSuiteResult.fromJson(suite.toJson());
      expect(restored.results, hasLength(5));
      expect(restored.overallStatus, BenchmarkStatus.error);
    });
  });
}
