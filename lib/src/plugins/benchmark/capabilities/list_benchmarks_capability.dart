/// `benchmark.list` capability — discovers registered scenarios (FR-002,
/// FR-011).
library;

import '../../../core/plugin_system/capability.dart';
import '../benchmark_plugin.dart';

/// Lists every registered benchmark scenario with its metadata.
class ListBenchmarksCapability extends ZuraffaCapability {
  /// Creates the list capability bound to [plugin].
  ListBenchmarksCapability(this.plugin);

  /// The owning benchmark plugin.
  final BenchmarkPlugin plugin;

  @override
  String get name => 'benchmark.list';

  @override
  String get description =>
      'Lists every registered benchmark scenario with name, version, '
      'description, tags and thresholds.';

  @override
  JsonSchema get inputSchema => const {
        'type': 'object',
        'properties': {},
      };

  @override
  JsonSchema get outputSchema => const {
        'type': 'object',
        'properties': {
          'scenarios': {'type': 'array'},
        },
      };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    return EffectReport(
      planId: 'benchmark.list.${DateTime.now().microsecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: [
        Effect(
          file: '(registry query)',
          action: 'read',
        ),
      ],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    await plugin.discoverAndRegisterScenarios();
    return plugin.listBenchmarks();
  }
}
