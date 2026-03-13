import 'package:args/command_runner.dart';
import '../../commands/graphql_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
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
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = GraphqlPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
      return delegator.generate(config);
    }

    if (!config.generateGql) {
      return [];
    }
    return graphqlBuilder.generate(config);
  }
}
