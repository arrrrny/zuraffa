import 'dart:io';

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

    // Issue #767: every failure path below exits non-zero — this command is
    // the tail of the dry-run → plan → apply pipeline the manifest
    // advertises to automation (an agent previews, stores, applies later).
    // Exit-code protocol: 64 = bad request (addressing/validity),
    // 1 = runtime failure, mirroring the shared CapabilityCommand runner.
    if (plan == null) {
      print('❌ Plan not found: $planId');
      exitCode = 64;
      return;
    }

    if (!plan.isValid) {
      print('❌ Plan is invalid: ${plan.message}');
      exitCode = 64;
      return;
    }

    final plugin = registry.getById(plan.pluginId);
    if (plugin == null) {
      print('❌ Plugin not found: ${plan.pluginId}');
      exitCode = 64;
      return;
    }

    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == plan.capabilityName,
      orElse: () =>
          throw Exception('Capability not found: ${plan.capabilityName}'),
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
      // Issue #767: same contract as CapabilityCommand — a failed
      // application reports failure to automation (exit 1).
      exitCode = 1;
    }
  }
}
