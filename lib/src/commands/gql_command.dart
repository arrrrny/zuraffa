import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/gql/gql_plugin.dart';
import '../plugins/gql/capabilities/create_gql_capability.dart';

class GqlCommand extends PluginCommand {
  @override
  final GqlPlugin plugin;

  GqlCommand(this.plugin) : super(plugin) {
    argParser.addOption('returns', help: 'GraphQL return fields');
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'GraphQL operation type (query, mutation)',
      defaultsTo: 'query',
    );
  }

  @override
  String get name => 'gql';

  @override
  String get description => 'Generate internal GQL query/mutation strings';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }
    final entityName = argResults!.rest.first;
    final type = argResults!['type'] as String?;
    final returns = argResults!['returns'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateGqlCapability)
            as CreateGqlCapability;

    final result = await capability.execute({
      'name': entityName,
      'type': type,
      'returns': returns,
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
      print('Failed to generate gql');
    }
  }
}
