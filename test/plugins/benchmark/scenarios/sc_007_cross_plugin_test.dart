@Tags(['slow'])
// Success criterion SC-007 (specs/015-benchmark-plugin/spec.md):
// cross-plugin compatibility — benchmarks from 3+ different plugins can
// run in the same suite without conflicts.
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/benchmark/benchmark_plugin.dart';

void main() {
  test('3+ plugins coexist in one suite', () async {
    final analytics = _AnalyticsPlugin();
    final sync = _SyncPlugin();
    final cache = _CachePlugin();

    // All three plugins register into the SAME suite (one BenchmarkPlugin
    // instance = one app), each through the provider contract.
    final benchmarkPlugin = BenchmarkPlugin();
    benchmarkPlugin.registerScenarioProvider(analytics);
    benchmarkPlugin.registerScenarioProvider(sync);
    benchmarkPlugin.registerScenarioProvider(cache);

    await benchmarkPlugin.discoverAndRegisterScenarios();

    // All scenarios from all plugins are present and runnable together.
    final all = await benchmarkPlugin.registry.getAll();
    expect(all, hasLength(4));
    expect(
      all.map((s) => s.id),
      containsAll([
        'analytics-aggregate-benchmark',
        'sync-push-benchmark',
        'sync-pull-benchmark',
        'cache-eviction-benchmark',
      ]),
    );

    // Run the mixed suite through the real runner.
    final runner = DefaultBenchmarkRunner();
    final suite = await runner.run(all);

    expect(suite.results, hasLength(4));
    expect(suite.overallStatus, BenchmarkStatus.passed);

    // No cross-contamination: each scenario's custom metrics land only in
    // its own result, under its own namespace.
    for (final result in suite.results) {
      expect(result.metrics, containsPair('${result.scenarioId}_ops', 1));
      for (final other in suite.results) {
        if (other.scenarioId == result.scenarioId) continue;
        expect(
          result.metrics.containsKey('${other.scenarioId}_ops'),
          isFalse,
          reason:
              '${result.scenarioId} leaked metrics from '
              '${other.scenarioId}',
        );
      }
    }

    // Shared state isolation: the three plugins' counters advanced exactly
    // by their own scenario counts.
    expect(analytics.executionCount, 1);
    expect(sync.executionCount, 2);
    expect(cache.executionCount, 1);
  });
}

// --- Three independent "plugins", each with its own scenario family. ---

class _AnalyticsPlugin implements BenchmarkScenarioProvider {
  int executionCount = 0;

  @override
  List<BenchmarkContract> provideScenarios() => [
    _PluginScenario(this, 'analytics-aggregate-benchmark'),
  ];
}

class _SyncPlugin implements BenchmarkScenarioProvider {
  int executionCount = 0;

  @override
  List<BenchmarkContract> provideScenarios() => [
    _PluginScenario(this, 'sync-push-benchmark'),
    _PluginScenario(this, 'sync-pull-benchmark'),
  ];
}

class _CachePlugin implements BenchmarkScenarioProvider {
  int executionCount = 0;

  @override
  List<BenchmarkContract> provideScenarios() => [
    _PluginScenario(this, 'cache-eviction-benchmark'),
  ];
}

/// A scenario bound to its owning plugin: records executions on the plugin
/// and namespaces its custom metrics by scenario id.
class _PluginScenario extends BenchmarkScenario {
  _PluginScenario(this._plugin, this._id);

  final BenchmarkScenarioProvider _plugin;
  final String _id;

  @override
  String get id => _id;

  @override
  String get name => 'Plugin scenario $_id';

  @override
  String get version => '1.0.0';

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    if (_plugin is _AnalyticsPlugin) {
      _plugin.executionCount++;
    } else if (_plugin is _SyncPlugin) {
      _plugin.executionCount++;
    } else if (_plugin is _CachePlugin) {
      _plugin.executionCount++;
    }
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: {'${_id}_ops': 1},
      thresholdViolations: const [],
      duration: const Duration(milliseconds: 1),
      timestamp: DateTime.now(),
    );
  }
}
