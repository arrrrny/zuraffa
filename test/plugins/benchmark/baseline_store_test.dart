// Tests for lib/src/core/benchmark/baseline_store.dart — behaviors
// U47–U56 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/baseline_store.dart';

void main() {
  late Directory tempDir;
  late JsonBaselineStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_baseline_test');
    store = JsonBaselineStore(directory: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Baseline baselineOf(
    String scenarioId, {
    String label = 'latest',
    Map<String, num> metrics = const {
      'latency_p99': 100,
      'throughput_ops_sec': 1000,
      'memory_mb': 50,
    },
    DateTime? timestamp,
  }) => Baseline(
    scenarioId: scenarioId,
    scenarioVersion: '1.0.0',
    label: label,
    metrics: metrics,
    timestamp: timestamp ?? DateTime.utc(2026, 8, 28),
    gitCommit: 'ab12cd34',
    gitBranch: 'main',
    environment: const {'os': 'linux', 'dart': '3.13.2'},
  );

  group('JsonBaselineStore', () {
    test('save then load', () async {
      await store.save(baselineOf('entity-crud-benchmark'));

      final loaded = await store.load('entity-crud-benchmark');
      expect(loaded, isNotNull);
      expect(loaded!.scenarioId, 'entity-crud-benchmark');
      expect(loaded.metrics['latency_p99'], 100);
      expect(loaded.gitCommit, 'ab12cd34');
    });

    test('load latest', () async {
      await store.save(
        baselineOf('scenario', label: 'old', timestamp: DateTime.utc(2026, 1)),
      );
      await store.save(
        baselineOf('scenario', label: 'new', timestamp: DateTime.utc(2026, 8)),
      );

      final loaded = await store.load('scenario');
      expect(loaded, isNotNull);
      expect(loaded!.label, 'new');
    });

    test('load by label', () async {
      await store.save(baselineOf('scenario', label: 'v1.0-release'));
      await store.save(baselineOf('scenario', label: 'weekly'));

      final loaded = await store.loadByLabel('scenario', 'v1.0-release');
      expect(loaded, isNotNull);
      expect(loaded!.label, 'v1.0-release');

      expect(await store.loadByLabel('scenario', 'missing'), isNull);
    });

    test('list ordered', () async {
      await store.save(
        baselineOf('scenario', label: 'b', timestamp: DateTime.utc(2026, 2)),
      );
      await store.save(
        baselineOf('scenario', label: 'a', timestamp: DateTime.utc(2026, 1)),
      );
      await store.save(
        baselineOf(
          'other-scenario',
          label: 'x',
          timestamp: DateTime.utc(2026, 3),
        ),
      );

      final list = await store.list('scenario');
      expect(list, hasLength(2));
      expect(list.map((b) => b.label).toList(), ['a', 'b']);

      final all = await store.listAll();
      expect(all, hasLength(3));
    });

    test('delete removes', () async {
      await store.save(baselineOf('scenario', label: 'keep'));
      await store.save(baselineOf('scenario', label: 'drop'));

      await store.delete('scenario', 'drop');

      expect(await store.loadByLabel('scenario', 'drop'), isNull);
      expect(await store.loadByLabel('scenario', 'keep'), isNotNull);
      expect((await store.list('scenario')), hasLength(1));
    });

    test('json round trip', () async {
      final baseline = baselineOf('round-trip-scenario');
      await store.save(baseline);

      final file = File('${tempDir.path}/round-trip-scenario.json');
      expect(await file.exists(), isTrue);
      final loaded = await store.load('round-trip-scenario');
      expect(loaded!.timestamp, baseline.timestamp);
      expect(loaded.environment, baseline.environment);
      expect(loaded.gitBranch, 'main');
      expect(loaded.scenarioVersion, '1.0.0');
    });

    test('load of unknown scenario is null', () async {
      expect(await store.load('never-saved'), isNull);
    });
  });

  group('Baseline comparison', () {
    test('compare percent changes', () {
      final baseline = baselineOf(
        'compare-scenario',
        metrics: const {
          'latency_p99': 100,
          'throughput_ops_sec': 1000,
          'memory_mb': 200,
        },
      );
      final current = const <String, num>{
        'latency_p99': 110,
        'throughput_ops_sec': 1200,
        'memory_mb': 200,
      };

      final comparison = compareBaselines(
        baseline,
        current,
        tolerancePercent: 10,
      );

      expect(comparison.scenarioId, 'compare-scenario');
      expect(comparison.changes.keys, containsAll(current.keys));

      final latency = comparison.changes['latency_p99']!;
      expect(latency.baselineValue, 100);
      expect(latency.currentValue, 110);
      expect(latency.percentChange, closeTo(10, 1e-9));
      // Latency is lower-is-better: +10% is a regression, but exactly at
      // tolerance -> stable.
      expect(latency.direction, MetricDirection.stable);
      expect(latency.isRegression, isFalse);

      final throughput = comparison.changes['throughput_ops_sec']!;
      expect(throughput.percentChange, closeTo(20, 1e-9));
      // Throughput is higher-is-better: +20% is an improvement.
      expect(throughput.direction, MetricDirection.improved);
      expect(throughput.isRegression, isFalse);

      final memory = comparison.changes['memory_mb']!;
      expect(memory.percentChange, 0);
      expect(memory.direction, MetricDirection.stable);
    });

    test('regression beyond tolerance', () {
      final baseline = baselineOf(
        'regression-scenario',
        metrics: const {'latency_p99': 100},
      );
      final comparison = compareBaselines(baseline, const {
        'latency_p99': 150,
      }, tolerancePercent: 10);

      final change = comparison.changes['latency_p99']!;
      expect(change.percentChange, closeTo(50, 1e-9));
      expect(change.direction, MetricDirection.regressed);
      expect(change.isRegression, isTrue);
      expect(change.severity, isNotNull);
      expect(change.tolerance, 10);

      expect(comparison.overallStatus, ComparisonStatus.regressed);
    });

    test('within tolerance stable', () {
      final baseline = baselineOf(
        'stable-scenario',
        metrics: const {'latency_p99': 100},
      );
      final comparison = compareBaselines(baseline, const {
        'latency_p99': 105,
      }, tolerancePercent: 10);

      expect(
        comparison.changes['latency_p99']!.direction,
        MetricDirection.stable,
      );
      expect(comparison.changes['latency_p99']!.isRegression, isFalse);
      expect(comparison.overallStatus, ComparisonStatus.stable);
    });

    test('improvement direction', () {
      final baseline = baselineOf(
        'improve-scenario',
        metrics: const {'latency_p99': 100, 'throughput_ops_sec': 1000},
      );
      final comparison = compareBaselines(baseline, const {
        'latency_p99': 50,
        'throughput_ops_sec': 900,
      }, tolerancePercent: 5);

      // Latency halved: improvement for a lower-is-better metric.
      expect(
        comparison.changes['latency_p99']!.direction,
        MetricDirection.improved,
      );
      // Throughput dropped 10% (> 5% tolerance): regression for a
      // higher-is-better metric.
      expect(
        comparison.changes['throughput_ops_sec']!.direction,
        MetricDirection.regressed,
      );
      expect(comparison.changes['throughput_ops_sec']!.isRegression, isTrue);
      expect(comparison.overallStatus, ComparisonStatus.regressed);
    });

    test('metrics missing from current are reported, not crashed', () {
      final baseline = baselineOf(
        'missing-metric-scenario',
        metrics: const {'latency_p99': 100, 'memory_mb': 50},
      );
      final comparison = compareBaselines(baseline, const {
        'latency_p99': 100,
      }, tolerancePercent: 10);

      expect(comparison.changes.containsKey('memory_mb'), isFalse);
      expect(comparison.overallStatus, ComparisonStatus.stable);
    });
  });
}
