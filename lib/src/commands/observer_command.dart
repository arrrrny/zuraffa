import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/observer/observer_plugin.dart';
import '../plugins/observer/capabilities/create_observer_capability.dart';

class ObserverCommand extends PluginCommand {
  @override
  final ObserverPlugin plugin;

  ObserverCommand(this.plugin) : super(plugin);

  @override
  String get name => 'observer';

  @override
  String get description => 'Generate Observer';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }
    final entityName = argResults!.rest.first;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateObserverCapability)
            as CreateObserverCapability;

    // Issue #1138: route the standalone invocation through the
    // CapabilityInvocationWrapper so a successful run persists its
    // proof.v1 receipt (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: plugin.id,
    );
    final result = await wrapper.execute({
      'name': entityName,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      // Bug #1139 (exit-code sweep, #856 pattern): a failed generation is a
      // failure — the process must never exit 0 after printing an error.
      print(
        '❌ Failed to generate observer: '
        '${result.message ?? "unknown error"}',
      );
      exitCode = 1;
    }
  }
}
