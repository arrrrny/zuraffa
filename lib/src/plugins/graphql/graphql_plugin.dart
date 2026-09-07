import 'package:args/command_runner.dart';

import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../commands/graphql_command.dart';
import 'builders/graphql_builder.dart';
import 'capabilities/create_graphql_capability.dart';

/// Generates GraphQL query/mutation string files from entity definitions.
///
/// Wraps [GraphqlBuilder] as a zuraffa plugin with CLI exposure.
class GraphqlPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;
  late final GraphqlBuilder graphqlBuilder;

  GraphqlPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    graphqlBuilder = GraphqlBuilder(outputDir: outputDir, options: options);
  }

  @override
  String get id => 'graphql';

  @override
  String get name => 'GraphQL Generator';

  @override
  String get version => '1.0.0';

  @override
  List<ZuraffaCapability> get capabilities => [CreateGraphqlCapability(this)];

  @override
  Command createCommand() => GraphqlCommand(this);

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'schema-path': {
        'type': 'string',
        'description': 'Path to .graphql schema file',
      },
      // Issue #1149: the operation-type and return-fields keys adopt the
      // deleted gql plugin's collision-free `gql-` prefix. The previous
      // `type` key collided with the usecase plugin's `type` schema
      // property (default `usecase`), so `zfa make X --methods=getList
      // --with=graphql` emitted `usecase CreateProduct` instead of a
      // GraphQL query.
      'gql-type': {
        'type': 'string',
        'description': 'GraphQL operation type (query, mutation, subscription)',
      },
      'gql-returns': {'type': 'string', 'description': 'GraphQL return fields'},
      'input-type': {'type': 'string', 'description': 'Input type name'},
      'input-name': {'type': 'string', 'description': 'Input variable name'},
      'op-name': {'type': 'string', 'description': 'Operation name'},
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
      // Issue #1149: read the collision-free `gql-` prefixed keys (folded
      // in from the deleted gql plugin) so the usecase plugin's `type`
      // default can no longer leak in as the GraphQL operation type.
      gqlReturns: context.get<String>('gql-returns'),
      gqlType: context.get<String>('gql-type'),
      gqlInputType: context.get<String>('input-type'),
      gqlInputName: context.get<String>('input-name'),
      gqlName: context.get<String>('op-name'),
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateGql && !config.revert) {
      return [];
    }
    return graphqlBuilder.generate(config);
  }
}
