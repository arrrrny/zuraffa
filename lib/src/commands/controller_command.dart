import 'dart:io';

import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/controller/controller_plugin.dart';

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

    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      generateController: true,
      generateState: generateState,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
