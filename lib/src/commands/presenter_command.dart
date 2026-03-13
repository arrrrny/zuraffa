import 'dart:io';

import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/presenter/capabilities/create_presenter_capability.dart';

class PresenterCommand extends PluginCommand {
  @override
  final PresenterPlugin plugin;

  PresenterCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addFlag(
      'di',
      help: 'Generate with DI integration',
      defaultsTo: true,
    );
  }

  @override
  String get name => 'presenter';

  @override
  String get description => 'Generate presenter class for an entity';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa presenter <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final methods =
        (argResults?['methods'] as String?)?.split(',') ?? ['get', 'update'];
    final generateDi = argResults?['di'] as bool? ?? true;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreatePresenterCapability)
            as CreatePresenterCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'di': generateDi,
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
      print('Failed to generate presenter');
    }
  }
}
