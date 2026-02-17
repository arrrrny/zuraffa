import 'package:args/command_runner.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plan_store.dart';

/// Command to apply a previously generated plan.
class ApplyCommand extends Command<void> {
  final PluginRegistry registry;

  ApplyCommand(this.registry) {
    argParser.addOption(
      'plan-id',
      help: 'The ID of the plan to execute',
      mandatory: true,
    );
  }

  @override
  String get name => 'apply';

  @override
  String get description => 'Execute a previously generated plan';

  @override
  Future<void> run() async {
    final planId = argResults!['plan-id'];
    final store = PlanStore.instance;
    final plan = await store.loadPlan(planId);

    if (plan == null) {
      print('❌ Plan not found: $planId');
      // exit(1);
      return;
    }

    if (!plan.isValid) {
      print('❌ Plan is invalid: ${plan.message}');
      return;
    }

    final plugin = registry.getById(plan.pluginId);
    if (plugin == null) {
      print('❌ Plugin not found: ${plan.pluginId}');
      return;
    }

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == plan.capabilityName,
      orElse: () => throw Exception('Capability not found: ${plan.capabilityName}'),
    );

    print('🚀 Executing plan $planId (${plugin.id}:${capability.name})...');
    
    final result = await capability.execute(plan.args);
    
    if (result.success) {
      print('✅ Success! Created/Modified:');
      for (final file in result.files) {
        print('  $file');
      }
      // Optionally delete plan after successful execution
      await store.deletePlan(planId);
    } else {
      print('❌ Failed: ${result.message}');
    }
  }
}
