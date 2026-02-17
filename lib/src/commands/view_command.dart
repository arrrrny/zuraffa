import 'dart:io';

import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/view/capabilities/create_view_capability.dart';

class ViewCommand extends PluginCommand {
  @override
  final ViewPlugin plugin;

  ViewCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    argParser.addFlag(
      'di',
      help: 'Generate with DI integration',
      defaultsTo: true,
    );
    argParser.addFlag(
      'state',
      help: 'Generate with State integration',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'view';

  @override
  String get description => 'Generate view class for an entity';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa view <EntityName> [options]');
      exit(1);
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final generateDi = argResults!['di'] as bool;
    final generateState = argResults!['state'] as bool;

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateViewCapability,
    ) as CreateViewCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'di': generateDi,
      'state': generateState,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate view');
    }
  }
}
