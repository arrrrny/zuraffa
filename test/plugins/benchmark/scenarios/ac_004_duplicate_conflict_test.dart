// Acceptance test AC-4 (specs/015-benchmark-plugin/spec.md US2):
// registering a duplicate scenario id returns a conflict error and leaves
// the original registration intact.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_registry.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('duplicate id conflicts', () async {
    final registry = InMemoryBenchmarkRegistry();
    await registry.register(FakeScenario('shared-benchmark'));
    final result =
        await registry.register(FakeScenario('shared-benchmark'));

    expect(result.isFailure, isTrue);
    final error = result.getFailureOrNull()!;
    expect(
      error.code,
      BenchmarkRegistryErrorCode.duplicateScenarioId,
    );
    expect(error.message, contains('shared-benchmark'));

    // The original registration is intact.
    expect((await registry.getAll()), hasLength(1));
    final original = await registry.get('shared-benchmark');
    expect(original, isNotNull);
    expect(original!.name, isNotEmpty);
  });
}
