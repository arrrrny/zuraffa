import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/repository/repository_plugin.dart';

class RepositoryCommand extends PluginCommand {
  @override
  final RepositoryPlugin plugin;

  RepositoryCommand(this.plugin) : super(plugin) {
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
    final entityName = argResults!.rest.first;
    final generateData = argResults!['data'] as bool;
    final generateDataSource = argResults!['datasource'] as bool;

    final config = GeneratorConfig(
      name: entityName,
      generateRepository: true,
      generateData: generateData,
      generateDataSource: generateDataSource,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
