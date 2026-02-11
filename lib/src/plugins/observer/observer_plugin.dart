import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/observer_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class ObserverPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  ObserverPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'observer';

  @override
  String get name => 'Observer Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateObserver) {
      return [];
    }
    final generator = ObserverGenerator(
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
