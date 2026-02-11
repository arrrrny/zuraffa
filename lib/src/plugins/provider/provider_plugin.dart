import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/provider_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class ProviderPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  ProviderPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'provider';

  @override
  String get name => 'Provider Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.hasService || !config.generateData) {
      return [];
    }

    final generator = ProviderGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final file = await generator.generate();
    return [file];
  }
}
