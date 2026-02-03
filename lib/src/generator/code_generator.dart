import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import 'repository_generator.dart';
import 'usecase_generator.dart';
import 'vpc_generator.dart';
import 'state_generator.dart';
import 'observer_generator.dart';
import 'data_layer_generator.dart';
import 'test_generator.dart';
import 'mock_generator.dart';
import 'di_generator.dart';
import 'cache_generator.dart';
import 'method_appender.dart';

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
  late final TestGenerator _testGenerator;

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
    _testGenerator = TestGenerator(
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
      // Handle --append mode
      if (config.appendToExisting) {
        final appender = MethodAppender(
          config: config,
          outputDir: outputDir,
          verbose: verbose,
        );
        final appendResult = await appender.appendMethod();

        // Generate UseCase file
        if (config.isPolymorphic) {
          final polymorphicFiles =
              await _useCaseGenerator.generatePolymorphic();
          files.addAll(polymorphicFiles);
        } else if (config.isOrchestrator) {
          final file = await _useCaseGenerator.generateOrchestrator();
          files.add(file);
        } else {
          final file = await _useCaseGenerator.generateCustom();
          files.add(file);
        }

        // Add updated files to the main list
        files.addAll(appendResult.updatedFiles);

        // Add warnings to next steps
        if (appendResult.warnings.isNotEmpty) {
          nextSteps.addAll(appendResult.warnings.map((w) => '⚠️  $w'));
        }

        return GeneratorResult(
          name: config.name,
          success: true,
          files: files,
          errors: errors,
          nextSteps: nextSteps,
        );
      }

      // Generate repository for entity-based operations only
      if (config.isEntityBased) {
        final file = await _repositoryGenerator.generate();
        files.add(file);

        for (final method in config.methods) {
          final file = await _useCaseGenerator.generateForMethod(method);
          files.add(file);
        }
      } else if (config.isPolymorphic) {
        // Generate polymorphic UseCases (abstract + variants + factory)
        final polymorphicFiles = await _useCaseGenerator.generatePolymorphic();
        files.addAll(polymorphicFiles);
      } else if (config.isOrchestrator) {
        // Generate orchestrator UseCase
        final file = await _useCaseGenerator.generateOrchestrator();
        files.add(file);
      } else if (config.isCustomUseCase) {
        // Generate custom UseCase
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
        // Always generate abstract datasource first
        final file = await _dataLayerGenerator.generateDataSource();
        files.add(file);

        if (config.enableCache) {
          // Generate both remote and local datasources
          final remoteFile =
              await _dataLayerGenerator.generateRemoteDataSource();
          final localFile = await _dataLayerGenerator.generateLocalDataSource();
          files.add(remoteFile);
          files.add(localFile);
          nextSteps.add(
              'Implement remote and local data sources for ${config.name}');
        } else {
          nextSteps.add(
              'Create a DataSource that implements ${config.name}DataSource in data layer');
        }
      }

      if (config.generateData) {
        final file = await _dataLayerGenerator.generateDataRepository();
        files.add(file);
      }

      // Generate mock data and/or mock data source
      if (config.generateMock || config.generateMockDataOnly) {
        final mockFiles = await MockGenerator.generate(
          config,
          outputDir,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        files.addAll(mockFiles);

        if (config.generateMockDataOnly) {
          nextSteps
              .add('Use ${config.name}MockData in your tests and UI previews');
        } else {
          nextSteps
              .add('Use ${config.name}MockDataSource for rapid prototyping');
          nextSteps.add('Switch to real DataSource implementation when ready');
        }
      }

      if (config.generateRepository &&
          !(config.generateData || config.generateDataSource)) {
        nextSteps.add('Implement Data${config.name}Repository in data layer');
      }
      if (config.effectiveRepos.isNotEmpty) {
        nextSteps.add('Register repositories with DI container');
      }
      if (files.any((f) => f.type == 'usecase' && (!config.isEntityBased))) {
        nextSteps.add('Implement TODO sections in generated usecases');
      }

      if (config.generateTest && config.isEntityBased) {
        for (final method in config.methods) {
          final file = await _testGenerator.generateForMethod(method);
          files.add(file);
        }
        nextSteps.add('Run tests: flutter test ');
      }

      if (config.generateTest && config.isOrchestrator) {
        final file = await _testGenerator.generateOrchestrator();
        files.add(file);
        nextSteps.add('Run tests: flutter test ');
      }

      if (config.generateTest && config.isPolymorphic) {
        final testFiles = await _testGenerator.generatePolymorphic();
        files.addAll(testFiles);
        nextSteps.add('Run tests: flutter test ');
      }

      if (config.generateTest &&
          config.isCustomUseCase &&
          !config.isPolymorphic &&
          !config.isOrchestrator) {
        final file = await _testGenerator.generateCustom();
        files.add(file);
        nextSteps.add('Run tests: flutter test ');
      }

      // Generate DI files if requested
      if (config.generateDi) {
        final diGenerator = DiGenerator(
          config: config,
          outputDir: outputDir,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        final diFiles = await diGenerator.generate();
        files.addAll(diFiles);

        // Generate cache init files if caching is enabled
        if (config.enableCache) {
          final cacheGenerator = CacheGenerator(
            config: config,
            outputDir: outputDir,
            dryRun: dryRun,
            force: force,
            verbose: verbose,
          );
          final cacheFiles = await cacheGenerator.generate();
          files.addAll(cacheFiles);
          nextSteps.add('Run: dart run build_runner build');
        }

        nextSteps.add('Import and call setupDependencies() in your main.dart');
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
