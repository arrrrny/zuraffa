import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/test_builder.dart';

class TestPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final TestBuilder testBuilder;

  TestPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    testBuilder = TestBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

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

    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      for (final method in config.methods) {
        files.add(await testBuilder.generateForMethod(config, method));
      }
    }

    if (config.isOrchestrator) {
      files.add(await testBuilder.generateOrchestrator(config));
    }

    if (config.isPolymorphic) {
      files.addAll(await testBuilder.generatePolymorphic(config));
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      files.add(await testBuilder.generateCustom(config));
    }

    return files;
  }
}
