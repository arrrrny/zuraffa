@Tags(['slow'])
library;

// Success criterion SC-001 (specs/015-benchmark-plugin/spec.md):
// a new plugin can implement a benchmark scenario by implementing the
// contract interface in under 50 lines of code.
//
// The fixture file contains ONLY the scenario implementation (plus its
// imports); the test counts its lines mechanically.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_runner.dart';

import 'fixtures/line_count_scenario.dart';

void main() {
  test('scenario under 50 lines', () async {
    final source = File(
      'test/plugins/benchmark/scenarios/fixtures/line_count_scenario.dart',
    ).readAsStringSync();

    final totalLines = source.split('\n').length;
    final nonBlankLines = source
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;

    expect(
      totalLines,
      lessThan(50),
      reason: 'fixture scenario must be under 50 lines, was $totalLines',
    );
    expect(nonBlankLines, lessThan(50));

    // The scenario is fully functional through the real runner.
    final runner = DefaultBenchmarkRunner();
    final result = await runner.runSingle(const LineCountScenario());
    expect(result.status.name, 'passed');
    expect(result.metrics, containsPair('sorts', 100));
  });
}
