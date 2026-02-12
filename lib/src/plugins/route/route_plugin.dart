import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/route_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class RoutePlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  RoutePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'route';

  @override
  String get name => 'Route Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateRoute) {
      return [];
    }
    final generator = RouteGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    return generator.generate();
  }
}
