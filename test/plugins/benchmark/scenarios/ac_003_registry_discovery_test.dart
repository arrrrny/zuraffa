// Acceptance test AC-3 (specs/015-benchmark-plugin/spec.md US2):
// registry discovery across 3+ plugins.
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/benchmark/benchmark_plugin.dart';

import '../helpers/fake_scenarios.dart';

void main() {
  test('registry returns all scenarios with metadata', () async {
    // Three distinct "plugins" contribute scenarios.
    final plugin = BenchmarkPlugin();
    plugin.registerScenarioProvider(_AnalyticsPluginProvider());
    plugin.registerScenarioProvider(_SyncPluginProvider());
    plugin.registerScenarioProvider(_CachePluginProvider());

    await plugin.discoverAndRegisterScenarios();

    final all = await plugin.registry.getAll();
    expect(all, hasLength(4));
    expect(
      all.map((s) => s.id),
      containsAll([
        'analytics-aggregation-benchmark',
        'sync-conflict-resolution-benchmark',
        'cache-hit-rate-benchmark',
        'cache-eviction-benchmark',
      ]),
    );

    // Every scenario carries its metadata (AC-3).
    for (final scenario in all) {
      expect(scenario.name, isNotEmpty);
      expect(scenario.version, isNotEmpty);
      expect(scenario.configSchema, isA<Map<String, dynamic>>());
    }

    final tagged = await plugin.registry.getByTags(['cache']);
    expect(tagged, hasLength(2));
  });
}

class _AnalyticsPluginProvider implements BenchmarkScenarioProvider {
  @override
  List<BenchmarkContract> provideScenarios() => [
    RecordingScenario(
      'analytics-aggregation-benchmark',
      name: 'Analytics Aggregation',
      tags: ['analytics'],
    ),
  ];
}

class _SyncPluginProvider implements BenchmarkScenarioProvider {
  @override
  List<BenchmarkContract> provideScenarios() => [
    RecordingScenario(
      'sync-conflict-resolution-benchmark',
      name: 'Sync Conflict Resolution',
      tags: ['sync'],
    ),
  ];
}

class _CachePluginProvider implements BenchmarkScenarioProvider {
  @override
  List<BenchmarkContract> provideScenarios() => [
    RecordingScenario(
      'cache-hit-rate-benchmark',
      name: 'Cache Hit Rate',
      tags: ['cache'],
    ),
    RecordingScenario(
      'cache-eviction-benchmark',
      name: 'Cache Eviction',
      tags: ['cache'],
    ),
  ];
}
