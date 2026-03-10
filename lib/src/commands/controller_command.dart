import 'dart:io';

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
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
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
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa controller <EntityName> [options]');
      exit(1);
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final generateState = argResults!['state'] as bool;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateControllerCapability)
            as CreateControllerCapability;

    final result = await capability.execute({
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
      print('Failed to generate controller');
    }
  }
}
