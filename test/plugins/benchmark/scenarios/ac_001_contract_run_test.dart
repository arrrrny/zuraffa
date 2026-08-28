// Acceptance test AC-1 (specs/015-benchmark-plugin/spec.md US1):
// a plugin developer implements BenchmarkContract and runs it through the
// runner, receiving a structured result with metrics.
//
// Drives the real entry point: DefaultBenchmarkRunner.runSingle on a
// hand-written contract implementation (pure interface, no base class —
// FR-015).
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

void main() {
  test('contract run returns structured result', () async {
    const scenario = StringConcatBenchmark();
    final runner = DefaultBenchmarkRunner();

    final result = await runner.runSingle(
      scenario,
      config: const {'pieces': 200},
    );

    expect(result.scenarioId, 'string-concat-benchmark');
    expect(result.scenarioName, 'String Concatenation');
    expect(result.scenarioVersion, '1.0.0');
    expect(result.status, BenchmarkStatus.passed);
    // Structured metrics present: the scenario's own plus the standard set.
    expect(result.metrics, containsPair('concatenations', 200));
    expect(result.metrics.containsKey('latency_p99'), isTrue);
    expect(result.metrics.containsKey('throughput_ops_sec'), isTrue);
    // Metadata carries the executed config.
    expect(result.metadata['config'], containsPair('pieces', 200));
    expect(result.duration, greaterThan(Duration.zero));
    expect(result.timestamp, isNotNull);
  });
}

/// A hand-written scenario implementing ONLY the BenchmarkContract interface
/// (no convenience base class) — the FR-015 decoupling proof.
class StringConcatBenchmark implements BenchmarkContract {
  const StringConcatBenchmark();

  @override
  String get id => 'string-concat-benchmark';

  @override
  String get name => 'String Concatenation';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Measures string building throughput.';

  @override
  Map<String, dynamic> get configSchema => const {
        'type': 'object',
        'properties': {
          'pieces': {'type': 'integer', 'minimum': 1, 'default': 100},
        },
      };

  @override
  Map<String, ThresholdConfig> get thresholds => const {};

  @override
  List<String> get tags => const [];

  @override
  Future<void> setup() async {}

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final pieces = (config['pieces'] as num?)?.toInt() ?? 100;
    final buffer = StringBuffer();
    for (var i = 0; i < pieces; i++) {
      buffer.write('piece-$i;');
    }
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: {'concatenations': pieces},
      thresholdViolations: const [],
      duration: Duration.zero,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> teardown() async {}

  @override
  Future<Map<String, num>> collectMetrics() async => const {};
}
