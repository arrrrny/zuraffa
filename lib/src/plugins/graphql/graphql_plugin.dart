import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/graphql_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class GraphqlPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  GraphqlPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'graphql';

  @override
  String get name => 'GraphQL Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateGql) {
      return [];
    }
    final generator = GraphQLGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    return generator.generate();
  }
}
