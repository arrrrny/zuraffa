// Fixture for SC-001: a complete, working benchmark scenario. Kept under 50
// lines TOTAL (including imports and comments) — the test counts them.
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';

/// Sorts integer lists — a realistic plugin-contributed workload.
class LineCountScenario extends BenchmarkScenario {
  const LineCountScenario();

  @override
  String get id => 'int-sort-benchmark';

  @override
  String get name => 'Integer Sort';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Sorts 10k integers per iteration.';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final sorts = (config['sorts'] as num?)?.toInt() ?? 100;
    var sink = 0;
    for (var s = 0; s < sorts; s++) {
      final list = List<int>.generate(10000, (i) => (i * 7919) % 10007);
      list.sort();
      sink += list.first;
    }
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: {'sorts': sorts, 'sink': sink},
      thresholdViolations: const [],
      duration: Duration.zero,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<Map<String, num>> collectMetrics() async => const {'sorted': 1};
}
