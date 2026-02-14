import 'dart:io';

import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/route/route_plugin.dart';

class RouteCommand extends PluginCommand {
  @override
  final RoutePlugin plugin;

  RouteCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
  }

  @override
  String get name => 'route';

  @override
  String get description => 'Generate route definitions for an entity';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('❌ Usage: zfa route <EntityName> [options]');
      exit(1);
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');

    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      generateRoute: true,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
