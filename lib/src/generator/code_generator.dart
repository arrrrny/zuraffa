import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import 'repository_generator.dart';
import 'usecase_generator.dart';
import 'vpc_generator.dart';
import 'state_generator.dart';
import 'observer_generator.dart';
import 'data_layer_generator.dart';

class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final RepositoryGenerator _repositoryGenerator;
  late final UseCaseGenerator _useCaseGenerator;
  late final VpcGenerator _vpcGenerator;
  late final StateGenerator _stateGenerator;
  late final ObserverGenerator _observerGenerator;
  late final DataLayerGenerator _dataLayerGenerator;

  CodeGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  }) {
    _repositoryGenerator = RepositoryGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _useCaseGenerator = UseCaseGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _vpcGenerator = VpcGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _stateGenerator = StateGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _observerGenerator = ObserverGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _dataLayerGenerator = DataLayerGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  Future<GeneratorResult> generate() async {
    final files = <GeneratedFile>[];
    final errors = <String>[];
    final nextSteps = <String>[];

    try {
      if (config.generateRepository) {
        final file = await _repositoryGenerator.generate();
        files.add(file);
      }

      if (config.isEntityBased) {
        for (final method in config.methods) {
          final file = await _useCaseGenerator.generateForMethod(method);
          files.add(file);
        }
      } else if (config.isCustomUseCase) {
        final file = await _useCaseGenerator.generateCustom();
        files.add(file);
      }

      if (config.generateVpc || config.generatePresenter) {
        final file = await _vpcGenerator.generatePresenter();
        files.add(file);
      }

      if (config.generateVpc || config.generateController) {
        final file = await _vpcGenerator.generateController();
        files.add(file);
      }

      if (config.generateVpc || config.generateView) {
        final file = await _vpcGenerator.generateView();
        files.add(file);
      }

      if (config.generateState) {
        final file = await _stateGenerator.generate();
        files.add(file);
      }

      if (config.generateObserver) {
        final file = await _observerGenerator.generate();
        files.add(file);
      }

      if (config.generateData || config.generateDataSource) {
        nextSteps.add(
            'Create a DataSource that implements ${config.name}DataSource in data layer');
        final file = await _dataLayerGenerator.generateDataSource();
        files.add(file);
      }

      if (config.generateData) {
        final file = await _dataLayerGenerator.generateDataRepository();
        files.add(file);
      }

      if (config.generateRepository &&
          !(config.generateData || config.generateDataSource)) {
        nextSteps.add('Implement Data${config.name}Repository in data layer');
      }
      if (config.effectiveRepos.isNotEmpty) {
        nextSteps.add('Register repositories with DI container');
      }
      if (files.any((f) => f.type == 'usecase')) {
        nextSteps.add('Implement TODO sections in generated usecases');
      }

      return GeneratorResult(
        success: true,
        name: config.name,
        files: files,
        errors: [],
        nextSteps: nextSteps,
      );
    } catch (e) {
      errors.add(e.toString());
      return GeneratorResult(
        success: false,
        name: config.name,
        files: files,
        errors: errors,
        nextSteps: [],
      );
    }
  }
}
