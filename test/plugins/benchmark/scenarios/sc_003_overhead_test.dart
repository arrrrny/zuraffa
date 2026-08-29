// Success criterion SC-003 (specs/015-benchmark-plugin/spec.md):
// benchmark execution adds less than 5% overhead to the measured operation
// (framework overhead).
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

void main() {
  // A compute-bound workload big enough that harness bookkeeping is noise
  // (~2-5ms per iteration on a typical dev machine).
  int workload() {
    var sink = 0.0;
    for (var i = 1; i <= 3000000; i++) {
      sink += 1.0 / i;
    }
    return sink.toInt();
  }

  test('overhead under 5 percent', () async {
    const iterations = 30;

    // Minimum of five raw measurements (least-noise estimate: filters
    // scheduler contention spikes): the workload looped directly.
    Future<Duration> minRaw() async {
      var best = const Duration(days: 1);
      for (var run = 0; run < 5; run++) {
        workload(); // JIT warm-up
        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          workload();
        }
        stopwatch.stop();
        if (stopwatch.elapsed < best) best = stopwatch.elapsed;
        await Future<void>.delayed(Duration.zero);
      }
      return best;
    }

    // Minimum of five framed measurements: the same workload driven
    // through the runner's full per-scenario pipeline (lifecycle, timing,
    // standard metrics, threshold evaluation, result construction).
    Future<Duration> minFramed(DefaultBenchmarkRunner runner) async {
      var best = const Duration(days: 1);
      for (var run = 0; run < 5; run++) {
        final stopwatch = Stopwatch()..start();
        final result = await runner.runSingle(
          _OverheadScenario(workload),
          config: const {'iterations': iterations},
        );
        stopwatch.stop();
        expect(result.status, BenchmarkStatus.passed);
        if (stopwatch.elapsed < best) best = stopwatch.elapsed;
      }
      return best;
    }

    // One runner, warmed up first so the git-commit lookup (cached per
    // runner) and JIT paths do not pollute the measurement.
    final runner = DefaultBenchmarkRunner();
    await runner.runSingle(
      _OverheadScenario(workload),
      config: const {'iterations': 1},
    );

    final raw = await minRaw();
    final framed = await minFramed(runner);

    final overhead =
        (framed.inMicroseconds - raw.inMicroseconds) / raw.inMicroseconds;

    expect(
      overhead,
      lessThan(0.05),
      reason:
          'framework overhead was '
          '${(overhead * 100).toStringAsFixed(1)}% '
          '(raw=${raw.inMilliseconds}ms, framed=${framed.inMilliseconds}ms)',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _OverheadScenario extends BenchmarkScenario {
  _OverheadScenario(this.workload);

  final int Function() workload;

  @override
  String get id => 'overhead-scenario';

  @override
  String get name => 'Overhead Measurement';

  @override
  String get version => '1.0.0';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    workload();
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: const {},
      thresholdViolations: const [],
      duration: Duration.zero,
      timestamp: DateTime.now(),
    );
  }
}
