import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/repository/capabilities/create_repository_capability.dart';

class RepositoryCommand extends PluginCommand {
  @override
  final RepositoryPlugin plugin;

  RepositoryCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: 'get,update',
    );
    argParser.addFlag(
      'data',
      help: 'Generate repository implementation',
      defaultsTo: true,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate data sources along with repository',
      defaultsTo: true,
    );
  }

  @override
  String get name => 'repository';

  @override
  String get description => 'Generate Repositories';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa repository <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final methods = (argResults?['methods'] as String?)?.split(',') ??
        ['get', 'update'];
    final generateData = argResults?['data'] as bool? ?? true;
    final generateDataSource = argResults?['datasource'] as bool? ?? true;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateRepositoryCapability)
            as CreateRepositoryCapability;

    final result = await capability.execute({
      'name': entityName,
      'methods': methods,
      'data': generateData,
      'datasource': generateDataSource,
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
      print('Failed to generate repository');
    }
  }
}
