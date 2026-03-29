import 'package:args/command_runner.dart';
import '../../commands/graphql_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/graphql_builder.dart';
import 'capabilities/create_graphql_capability.dart';

/// Manages GraphQL-related code generation.
///
/// Produces GraphQL query and mutation strings, and wires them into
/// remote data sources.
///
/// Example:
/// ```dart
/// final plugin = GraphqlPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class GraphqlPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final GraphqlBuilder graphqlBuilder;

  GraphqlPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    graphqlBuilder = GraphqlBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateGraphqlCapability(this)];

  @override
  Command createCommand() => GraphqlCommand(this);

  @override
  String get id => 'graphql';

  @override
  String get name => 'GraphQL Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'gql-returns': {'type': 'string', 'description': 'GraphQL return type'},
      'gql-type': {
        'type': 'string',
        'description': 'GraphQL operation type (query/mutation)',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateGql: true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      gqlReturns: context.get<String>('gql-returns'),
      gqlType: context.get<String>('gql-type'),
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateGql && !config.revert) {
      return [];
    }
    return graphqlBuilder.generate(config);
  }
}
