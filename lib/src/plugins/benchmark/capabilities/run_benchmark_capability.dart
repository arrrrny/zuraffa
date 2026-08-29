/// `benchmark.run` capability — executes registered scenarios (FR-004,
/// FR-011).
library;

import '../../../core/plugin_system/capability.dart';
import '../benchmark_plugin.dart';

/// Runs the registered benchmark scenarios through the standard runner.
class RunBenchmarkCapability extends ZuraffaCapability {
  /// Creates the run capability bound to [plugin].
  RunBenchmarkCapability(this.plugin);

  /// The owning benchmark plugin.
  final BenchmarkPlugin plugin;

  @override
  String get name => 'benchmark.run';

  @override
  String get description =>
      'Runs registered benchmark scenarios (all, or a filtered subset) and '
      'returns the aggregate suite result with standardized metrics and '
      'threshold verdicts.';

  @override
  JsonSchema get inputSchema => const {
    'type': 'object',
    'properties': {
      'scenarioIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Scenario ids to run; omit to run all.',
      },
      'config': {
        'type': 'object',
        'description': 'Global config merged under every scenario.',
      },
      'dryRun': {
        'type': 'boolean',
        'default': false,
        'description': 'Validate configurations without executing.',
      },
    },
  };

  @override
  JsonSchema get outputSchema => const {
    'type': 'object',
    'properties': {
      'suite': {'type': 'object'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final scenarioIds = (args['scenarioIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    return EffectReport(
      planId: 'benchmark.run.${DateTime.now().microsecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: [
        Effect(
          file: '(benchmark execution)',
          action: args['dryRun'] == true ? 'validate' : 'run',
          diff: scenarioIds.isEmpty
              ? 'run all registered scenarios'
              : 'run scenarios: ${scenarioIds.join(', ')}',
        ),
      ],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    await plugin.discoverAndRegisterScenarios();
    return plugin.runBenchmarks(
      scenarioIds: (args['scenarioIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      config: args['config'] as Map<String, dynamic>?,
      dryRun: args['dryRun'] == true,
    );
  }
}
