import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/controller/capabilities/create_controller_capability.dart';

class ControllerCommand extends PluginCommand {
  @override
  final ControllerPlugin plugin;

  ControllerCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addFlag(
      'state',
      help: 'Generate with State integration',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'controller';

  @override
  String get description => 'Generate controller class for an entity';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }

    final entityName = argResults!.rest.first;
    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];
    final generateState = argResults?['state'] as bool? ?? false;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateControllerCapability)
            as CreateControllerCapability;

    // Issue #1138: route the standalone invocation through the
    // CapabilityInvocationWrapper so a successful run persists its
    // proof.v1 receipt (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: plugin.id,
    );
    final result = await wrapper.execute({
      'name': entityName,
      'methods': methods,
      'state': generateState,
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
        '❌ Failed to generate controller: '
        '${result.message ?? "unknown error"}',
      );
      exitCode = 1;
    }
  }
}
