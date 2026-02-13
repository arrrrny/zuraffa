import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/graphql/graphql_plugin.dart';

class GraphqlCommand extends PluginCommand {
  @override
  final GraphqlPlugin plugin;

  GraphqlCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'GraphQL operation type (query, mutation)',
      defaultsTo: 'query',
    );
    argParser.addOption(
      'returns',
      help: 'Return type',
    );
    argParser.addOption(
      'input-type',
      help: 'Input type name',
    );
    argParser.addOption(
      'input-name',
      help: 'Input variable name',
    );
    argParser.addOption(
      'op-name',
      help: 'Operation name',
    );
  }

  @override
  String get name => 'graphql';

  @override
  String get description => 'Generate GraphQL files';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final type = argResults!['type'] as String?;
    final returns = argResults!['returns'] as String?;
    final inputType = argResults!['input-type'] as String?;
    final inputName = argResults!['input-name'] as String?;
    final opName = argResults!['op-name'] as String?;

    final config = GeneratorConfig(
      name: entityName,
      generateGql: true,
      gqlType: type,
      gqlReturns: returns,
      gqlInputType: inputType,
      gqlInputName: inputName,
      gqlName: opName,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
