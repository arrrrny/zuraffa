/// `benchmark.register` capability — registers scenarios from providers
/// (FR-003, FR-014).
library;

import '../../../core/plugin_system/capability.dart';
import '../benchmark_plugin.dart';

/// Registers provider-supplied (or explicitly listed) scenarios into the
/// registry at runtime.
class RegisterBenchmarkCapability extends ZuraffaCapability {
  /// Creates the register capability bound to [plugin].
  RegisterBenchmarkCapability(this.plugin);

  /// The owning benchmark plugin.
  final BenchmarkPlugin plugin;

  @override
  String get name => 'benchmark.register';

  @override
  String get description =>
      'Registers benchmark scenarios (discovered from registered providers '
      'or supplied directly) into the benchmark registry at runtime, without '
      'an app restart.';

  @override
  JsonSchema get inputSchema => const {
    'type': 'object',
    'properties': {
      'discover': {
        'type': 'boolean',
        'default': true,
        'description': 'Pull scenarios from registered providers.',
      },
    },
  };

  @override
  JsonSchema get outputSchema => const {
    'type': 'object',
    'properties': {
      'registered': {'type': 'number'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    return EffectReport(
      planId: 'benchmark.register.${DateTime.now().microsecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: [
        Effect(
          file: '(benchmark registry)',
          action: 'modify',
          diff: 'insert scenarios from providers',
        ),
      ],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final before = (await plugin.registry.getAll()).length;
    if (args['discover'] != false) {
      await plugin.discoverAndRegisterScenarios();
    }
    final scenarios = (await plugin.registry.getAll())
        .whereType<BenchmarkContract>()
        .toList();
    return ExecutionResult(
      success: true,
      data: {
        'registered': scenarios.length - before,
        'total': scenarios.length,
      },
    );
  }
}
