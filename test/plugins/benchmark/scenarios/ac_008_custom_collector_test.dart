@Tags(['slow'])
library;

// Acceptance test AC-8 (specs/015-benchmark-plugin/spec.md US4):
// a registered custom metric collector's data appears in the final
// benchmark result, collected at the right lifecycle points.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';
import 'package:zuraffa/src/core/benchmark/metric_collector.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('custom collector metrics appear in result', () async {
    final collector = _QueryCountCollector();
    final runner = DefaultBenchmarkRunner(collectors: [collector]);

    final result = await runner.runSingle(
      RecordingScenario('collector-integration-scenario'),
      config: const {'iterations': 3},
    );

    // The collector's data appears in the final result.
    expect(result.metrics, containsPair('db_query_count', 3));
    expect(result.metrics, containsPair('db_index_scans', 6));

    // The collector observed the right lifecycle points: after the
    // benchmark, with the scenario's partial result available.
    expect(collector.sawResultInCollect, isTrue);
    expect(collector.observedScenarioId, 'collector-integration-scenario');
  });
}

/// A domain-specific collector standing in for a plugin's custom metrics
/// (database query counting per research.md's example).
class _QueryCountCollector implements MetricCollector {
  bool sawResultInCollect = false;
  String? observedScenarioId;

  @override
  String get id => 'db-query-collector';

  @override
  String get name => 'Database Query Counter';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> beforeBenchmark(MetricContext context) async {
    observedScenarioId = context.scenarioId;
  }

  @override
  Future<Map<String, num>> collect(MetricContext context) async {
    if (context.result != null) sawResultInCollect = true;
    observedScenarioId = context.scenarioId;
    // Derive metrics from the observed execution: one query per iteration
    // plus two index scans per query.
    final iterations = context.samples.length;
    return {'db_query_count': iterations, 'db_index_scans': iterations * 2};
  }

  @override
  Future<void> finalize() async {}
}
