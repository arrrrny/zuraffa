import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/test_generator.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class TestPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  TestPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'test';

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateTest) {
      return [];
    }

    final generator = TestGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      for (final method in config.methods) {
        files.add(await generator.generateForMethod(method));
      }
    }

    if (config.isOrchestrator) {
      files.add(await generator.generateOrchestrator());
    }

    if (config.isPolymorphic) {
      files.addAll(await generator.generatePolymorphic());
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      files.add(await generator.generateCustom());
    }

    return files;
  }
}
