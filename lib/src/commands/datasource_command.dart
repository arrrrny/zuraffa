import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/datasource/datasource_plugin.dart';

class DataSourceCommand extends PluginCommand {
  @override
  final DataSourcePlugin plugin;

  DataSourceCommand(this.plugin) : super(plugin) {
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
    argParser.addFlag(
      'cache',
      help: 'Enable caching',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'datasource';

  @override
  String get description => 'Generate DataSources';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final generateLocal = argResults!['local'] as bool;
    final enableCache = argResults!['cache'] as bool;

    final config = GeneratorConfig(
      name: entityName,
      generateDataSource: true,
      generateLocal: generateLocal,
      enableCache: enableCache,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );
    
    final files = await plugin.generate(config);
    logSummary(files);
  }
}
