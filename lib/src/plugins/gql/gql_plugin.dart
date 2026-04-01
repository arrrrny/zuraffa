import '../../core/generator_options.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/gql_builder.dart';

/// Manages internal GraphQL string generation (internal data layer).
class GqlPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final GqlBuilder gqlBuilder;

  GqlPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    gqlBuilder = GqlBuilder(outputDir: outputDir, options: options);
  }

  @override
  String get id => 'gql';

  @override
  String get name => 'GQL String Builder';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'gqlByDefault';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'gql-returns': {'type': 'string', 'description': 'GraphQL return fields'},
      'gql-type': {'type': 'string', 'description': 'GraphQL operation type'},
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
    return gqlBuilder.generate(config);
  }
}
