import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/cache_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class CachePlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  CachePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'cache';

  @override
  String get name => 'Cache Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableCache) {
      return [];
    }
    final generator = CacheGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    return generator.generate();
  }
}
