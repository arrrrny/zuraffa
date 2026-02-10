import 'package:path/path.dart' as path;
import 'package:zuraffa/src/generator/data_layer_generator.dart';
import 'package:zuraffa/src/generator/repository_generator.dart';
import 'package:zuraffa/src/generator/usecase_generator.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';

class BaselineScenario {
  final String name;
  final GeneratorConfig config;

  const BaselineScenario({required this.name, required this.config});
}

class BaselineGenerator {
  Future<Map<String, String>> generate(
    BaselineScenario scenario, {
    required String outputDir,
  }) async {
    final config = scenario.config;
    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      final repositoryGenerator = RepositoryGenerator(
        config: config,
        outputDir: outputDir,
        dryRun: true,
        force: true,
        verbose: false,
      );
      files.add(await repositoryGenerator.generate());

      final dataLayerGenerator = DataLayerGenerator(
        config: config,
        outputDir: outputDir,
        dryRun: true,
        force: true,
        verbose: false,
      );
      if (config.generateData || config.generateDataSource) {
        if (config.generateLocal) {
          files.add(await dataLayerGenerator.generateLocalDataSource());
        } else {
          files.add(await dataLayerGenerator.generateRemoteDataSource());
        }
        if (config.enableCache && !config.generateLocal) {
          files.add(await dataLayerGenerator.generateLocalDataSource());
        }
        files.add(await dataLayerGenerator.generateDataSource());
        if (config.generateData) {
          files.add(await dataLayerGenerator.generateDataRepository());
        }
      }

      final useCaseGenerator = UseCaseGenerator(
        config: config,
        outputDir: outputDir,
        dryRun: true,
        force: true,
        verbose: false,
      );
      for (final method in config.methods) {
        files.add(await useCaseGenerator.generateForMethod(method));
      }
    }

    return _mapByRelativePath(files, outputDir);
  }

  Map<String, String> _mapByRelativePath(
    List<GeneratedFile> files,
    String outputDir,
  ) {
    final mapped = <String, String>{};
    for (final file in files) {
      final relative = path.relative(file.path, from: outputDir);
      mapped[relative] = file.content ?? '';
    }
    return mapped;
  }
}
