import 'dart:io';

import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/route/capabilities/create_route_capability.dart';

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

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateRouteCapability,
    ) as CreateRouteCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate route');
    }
  }
}
