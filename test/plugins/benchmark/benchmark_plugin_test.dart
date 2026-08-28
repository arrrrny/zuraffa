// Tests for lib/src/plugins/benchmark/benchmark_plugin.dart — behaviors
// U57–U60 of specs/015-benchmark-plugin/tdd/test-list.md.
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/benchmark/benchmark_plugin.dart';

import 'helpers/fake_scenarios.dart';

void main() {
  group('BenchmarkPlugin', () {
    test('plugin surface', () {
      final plugin = BenchmarkPlugin();

      expect(plugin.id, 'benchmark');
      expect(plugin.name, isNotEmpty);
      expect(plugin.version, isNotEmpty);

      final capabilityNames = plugin.capabilities.map((c) => c.name).toList();
      expect(capabilityNames, containsAll(['benchmark.run', 'benchmark.list',
          'benchmark.register']));
      // Every capability exposes schemas (plugin system contract).
      for (final capability in plugin.capabilities) {
        expect(capability.description, isNotEmpty);
        expect(capability.inputSchema, isNotEmpty);
        expect(capability.outputSchema, isNotEmpty);
      }
    });

    test('provider registers scenarios', () async {
      final plugin = BenchmarkPlugin();
      final provider = _FakeProvider([
        RecordingScenario('provider-scenario-a'),
        RecordingScenario('provider-scenario-b', tags: ['net']),
      ]);

      plugin.registerScenarioProvider(provider);
      await plugin.discoverAndRegisterScenarios();

      final registry = plugin.registry;
      expect(await registry.has('provider-scenario-a'), isTrue);
      expect(await registry.has('provider-scenario-b'), isTrue);

      final tagged = await registry.getByTags(['net']);
      expect(tagged.map((s) => s.id), ['provider-scenario-b']);
    });

    test('list capability', () async {
      final plugin = BenchmarkPlugin();
      plugin.registerScenarioProvider(
        _FakeProvider([RecordingScenario('list-scenario')]),
      );
      await plugin.discoverAndRegisterScenarios();

      final result = await plugin.listBenchmarks();
      expect(result.success, isTrue);
      final scenarios =
          result.data!['scenarios'] as List<Map<String, dynamic>>;
      expect(scenarios, hasLength(1));
      expect(scenarios.first['id'], 'list-scenario');
      expect(scenarios.first['version'], '1.0.0');
      expect(scenarios.first, containsPair('tags', isEmpty));
    });

    test('run capability', () async {
      final plugin = BenchmarkPlugin();
      plugin.registerScenarioProvider(
        _FakeProvider([
          RecordingScenario('run-scenario'),
          ThrowingScenario('run-broken', throwIn: LifecycleStage.run),
        ]),
      );
      await plugin.discoverAndRegisterScenarios();

      final result = await plugin.runBenchmarks();
      expect(result.success, isTrue);

      final suite = BenchmarkSuiteResult.fromJson(
        result.data!['suite'] as Map<String, dynamic>,
      );
      expect(suite.results, hasLength(2));
      expect(
        suite.results.map((r) => r.scenarioId),
        containsAll(['run-scenario', 'run-broken']),
      );
      // The broken scenario errored; the healthy one passed; the suite
      // continued (FR-013).
      final broken = suite.results
          .firstWhere((r) => r.scenarioId == 'run-broken');
      expect(broken.status, BenchmarkStatus.error);
      final healthy = suite.results
          .firstWhere((r) => r.scenarioId == 'run-scenario');
      expect(healthy.status, BenchmarkStatus.passed);
    });

    test('run capability filters by scenario id', () async {
      final plugin = BenchmarkPlugin();
      plugin.registerScenarioProvider(
        _FakeProvider([
          RecordingScenario('filter-a'),
          RecordingScenario('filter-b'),
        ]),
      );
      await plugin.discoverAndRegisterScenarios();

      final result = await plugin.runBenchmarks(scenarioIds: ['filter-b']);
      final suite = BenchmarkSuiteResult.fromJson(
        result.data!['suite'] as Map<String, dynamic>,
      );
      expect(suite.results, hasLength(1));
      expect(suite.results.first.scenarioId, 'filter-b');
    });
  });
}

/// A scenario provider standing in for a third-party plugin (SC-007 shape).
class _FakeProvider implements BenchmarkScenarioProvider {
  _FakeProvider(this.scenarios);

  final List<BenchmarkContract> scenarios;

  @override
  List<BenchmarkContract> provideScenarios() => scenarios;
}
