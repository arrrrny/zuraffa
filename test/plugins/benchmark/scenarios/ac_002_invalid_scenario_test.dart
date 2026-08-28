// Acceptance test AC-2 (specs/015-benchmark-plugin/spec.md US1):
// an invalid benchmark scenario is rejected with a clear validation error
// and is never executed.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_registry.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

void main() {
  test('invalid scenario rejected without execution', () async {
    final registry = InMemoryBenchmarkRegistry();
    final runner = DefaultBenchmarkRunner();
    final scenario = _InvalidScenario()..executions = 0;

    // Registration rejects the invalid scenario with a clear message.
    final registration = await registry.register(scenario);
    expect(registration.isFailure, isTrue);
    final error = registration.getFailureOrNull()!;
    expect(error.message, contains('kebab-case'));
    expect(await registry.getAll(), isEmpty);

    // Dry-run reports the same validation problem.
    final dry = await runner.dryRun(scenario);
    expect(dry.valid, isFalse);
    expect(dry.errors.join('\n'), contains('kebab-case'));

    // The scenario was never executed through any path.
    expect(scenario.executions, 0);
  });
}

class _InvalidScenario implements BenchmarkContract {
  int executions = 0;

  @override
  String get id => 'Not Kebab Case!';

  @override
  String get name => 'Invalid Scenario';

  @override
  String get version => 'not.a.version';

  @override
  String get description => '';

  @override
  Map<String, dynamic> get configSchema => const {};

  @override
  Map<String, ThresholdConfig> get thresholds => const {};

  @override
  List<String> get tags => const [];

  @override
  Future<void> setup() async {}

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    executions++;
    throw UnimplementedError();
  }

  @override
  Future<void> teardown() async {}

  @override
  Future<Map<String, num>> collectMetrics() async => const {};
}
