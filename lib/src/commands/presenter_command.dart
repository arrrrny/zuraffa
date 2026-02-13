import 'dart:io';

import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/presenter/presenter_plugin.dart';

class PresenterCommand extends PluginCommand {
  @override
  final PresenterPlugin plugin;

  PresenterCommand(this.plugin) : super(plugin) {
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
  }

  @override
  String get name => 'presenter';

  @override
  String get description => 'Generate presenter class for an entity';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa presenter <EntityName> [options]');
      exit(1);
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final generateDi = argResults!['di'] as bool;

    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      generatePresenter: true,
      generateDi: generateDi,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
