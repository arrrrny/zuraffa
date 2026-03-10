import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/datasource/datasource_plugin.dart';
import '../plugins/datasource/capabilities/create_datasource_capability.dart';

class DataSourceCommand extends PluginCommand {
  @override
  final DataSourcePlugin plugin;

  DataSourceCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    argParser.addFlag(
      'local',
      help: 'Generate local data source (and Hive/DB integration)',
      defaultsTo: true,
    );
    argParser.addFlag(
      'remote',
      help: 'Generate remote data source (and API integration)',
      defaultsTo: true,
    );
    argParser.addFlag('cache', help: 'Enable caching', defaultsTo: false);
  }

  @override
  String get name => 'datasource';

  @override
  String get description => 'Generate DataSources';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final generateLocal = argResults!['local'] as bool;
    final generateRemote = argResults!['remote'] as bool;
    final enableCache = argResults!['cache'] as bool;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateDataSourceCapability)
            as CreateDataSourceCapability;

    final result = await capability.execute({
      'name': entityName,
      'local': generateLocal,
      'remote': generateRemote,
      'cache': enableCache,
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
      print('Failed to generate datasource');
    }
  }
}
