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
      help: 'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
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
      print('   Or use a subcommand:');
      print('   zfa route create <EntityName> [options]');
      print('   zfa route custom <Name> [options]');
      return;
    }

    var entityName = argResults!.rest.first;
    var capabilityName = 'create';

    if (argResults!.rest.length > 1) {
      final first = argResults!.rest.first;
      if (first == 'create' || first == 'custom') {
        capabilityName = first;
        entityName = argResults!.rest[1];
      }
    }

    final methods = (argResults?['methods'] as String?)?.split(',') ??
        ['get', 'update'];

    final capability = plugin.capabilities
        .firstWhere((c) => c.name == capabilityName);

    final result = await capability.execute({
      'name': entityName,
      'methods': capabilityName == 'custom' ? [] : methods,
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
      print('Failed to generate route');
    }
  }
}
