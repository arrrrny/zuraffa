import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import 'repository_generator.dart';
import 'service_generator.dart';
import 'provider_generator.dart';
import 'usecase_generator.dart';
import 'vpc_generator.dart';
import 'state_generator.dart';
import 'observer_generator.dart';
import 'data_layer_generator.dart';
import 'test_generator.dart';
import 'mock_generator.dart';
import 'di_generator.dart';
import 'cache_generator.dart';
import 'graphql_generator.dart';
import 'route_generator.dart';
import 'method_appender.dart';
import '../core/transaction/generation_transaction.dart';

class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final RepositoryGenerator _repositoryGenerator;
  late final ServiceGenerator _serviceGenerator;
  late final ProviderGenerator _providerGenerator;
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
    _serviceGenerator = ServiceGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _providerGenerator = ProviderGenerator(
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
    final transaction = GenerationTransaction(dryRun: dryRun);

    return GenerationTransaction.run(transaction, () async {
      final files = <GeneratedFile>[];
      final errors = <String>[];
      final nextSteps = <String>[];

      Future<GeneratorResult> finalizeSuccess() async {
        final transactionResult = await transaction.commit();
        if (!transactionResult.success) {
          errors.addAll(
            transactionResult.conflicts.map((c) => 'Conflict: $c'),
          );
          errors.addAll(transactionResult.errors);
          return GeneratorResult(
            name: config.name,
            success: false,
            files: files,
            errors: errors,
            nextSteps: nextSteps,
          );
        }
        return GeneratorResult(
          name: config.name,
          success: true,
          files: files,
          errors: errors,
          nextSteps: nextSteps,
        );
      }

      try {
        if (config.appendToExisting) {
          final appender = MethodAppender(
            config: config,
            outputDir: outputDir,
            verbose: verbose,
            dryRun: dryRun,
          );
          final appendResult = await appender.appendMethod();

          if (config.isPolymorphic) {
            final polymorphicFiles = await _useCaseGenerator
                .generatePolymorphic();
            files.addAll(polymorphicFiles);
          } else if (config.isOrchestrator) {
            final file = await _useCaseGenerator.generateOrchestrator();
            files.add(file);
          } else {
            final file = await _useCaseGenerator.generateCustom();
            files.add(file);
          }

          files.addAll(appendResult.updatedFiles);

          if (appendResult.warnings.isNotEmpty) {
            nextSteps.addAll(appendResult.warnings.map((w) => '⚠️  $w'));
          }

          if (config.generateGql) {
            final graphqlGenerator = GraphQLGenerator(
              config: config,
              outputDir: outputDir,
              dryRun: dryRun,
              force: force,
              verbose: verbose,
            );
            final graphqlFiles = await graphqlGenerator.generate();
            files.addAll(graphqlFiles);
          }

          return finalizeSuccess();
        }

        if (config.isEntityBased) {
          final file = await _repositoryGenerator.generate();
          files.add(file);

          for (final method in config.methods) {
            final methodFile = await _useCaseGenerator.generateForMethod(method);
            files.add(methodFile);
          }
        } else if (config.isPolymorphic) {
          final polymorphicFiles = await _useCaseGenerator.generatePolymorphic();
          files.addAll(polymorphicFiles);
        } else if (config.isOrchestrator) {
          final orchestratorFile = await _useCaseGenerator.generateOrchestrator();
          files.add(orchestratorFile);
        } else if (config.isCustomUseCase) {
          if (config.hasService) {
            final serviceFile = await _serviceGenerator.generate();
            files.add(serviceFile);
          }
          final usecaseFile = await _useCaseGenerator.generateCustom();
          files.add(usecaseFile);
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
          if (config.hasService && config.generateData) {
            final providerFile = await _providerGenerator.generate();
            files.add(providerFile);
            nextSteps.add(
              'Implement ${config.effectiveProvider} with external service client',
            );
          } else {
            final dataSourceFile =
                await _dataLayerGenerator.generateDataSource();
            files.add(dataSourceFile);

            if (config.enableCache) {
              final remoteFile = await _dataLayerGenerator
                  .generateRemoteDataSource();
              final localFile = await _dataLayerGenerator
                  .generateLocalDataSource();
              files.add(remoteFile);
              files.add(localFile);
              nextSteps.add(
                'Implement remote and local data sources for ${config.name}',
              );
            } else {
              nextSteps.add(
                'Create a DataSource that implements ${config.name}DataSource in data layer',
              );
            }

            final dataRepoFile =
                await _dataLayerGenerator.generateDataRepository();
            files.add(dataRepoFile);
          }
        }

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
            nextSteps.add(
              'Use ${config.name}MockData in your tests and UI previews',
            );
          } else {
            nextSteps.add(
              'Use ${config.name}MockDataSource for rapid prototyping',
            );
            nextSteps.add(
              'Switch to real DataSource implementation when ready',
            );
          }
        }

        if (config.generateRepository &&
            !(config.generateData || config.generateDataSource)) {
          nextSteps.add('Implement Data${config.name}Repository in data layer');
        }
        if (config.effectiveRepos.isNotEmpty) {
          nextSteps.add('Register repositories with DI container');
        }
        if (config.hasService) {
          if (config.generateData) {
            nextSteps.add(
              'Implement ${config.effectiveProvider} with external service client',
            );
          } else {
            nextSteps.add(
              'Implement ${config.effectiveService} in data/providers layer',
            );
          }
          nextSteps.add('Register service provider with DI container');
        }
        if (files.any((f) => f.type == 'usecase' && (!config.isEntityBased))) {
          nextSteps.add('Implement TODO sections in generated usecases');
        }

        if (config.generateTest && config.isEntityBased) {
          for (final method in config.methods) {
            final testFile = await _testGenerator.generateForMethod(method);
            files.add(testFile);
          }
          nextSteps.add('Run tests: flutter test ');
        }

        if (config.generateTest && config.isOrchestrator) {
          final testFile = await _testGenerator.generateOrchestrator();
          files.add(testFile);
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
          final testFile = await _testGenerator.generateCustom();
          files.add(testFile);
          nextSteps.add('Run tests: flutter test ');
        }

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
        }

        if (config.generateRoute) {
          final routeGenerator = RouteGenerator(
            config: config,
            outputDir: outputDir,
            dryRun: dryRun,
            force: force,
            verbose: verbose,
          );
          final routeFiles = await routeGenerator.generate();
          files.addAll(routeFiles);
          nextSteps.add('Add go_router to your pubspec.yaml dependencies');
          nextSteps.add('Import routes from lib/src/routing/index.dart');
        }

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
          nextSteps.add('Call initAllCaches() before DI setup');
        }

        if (config.generateGql) {
          final graphqlGenerator = GraphQLGenerator(
            config: config,
            outputDir: outputDir,
            dryRun: dryRun,
            force: force,
            verbose: verbose,
          );
          final graphqlFiles = await graphqlGenerator.generate();
          files.addAll(graphqlFiles);
        }

        return finalizeSuccess();
      } catch (e, stack) {
        errors.add('Generation failed: $e');
        if (verbose) {
          errors.add('Stack trace:\n$stack');
        }
        return GeneratorResult(
          name: config.name,
          success: false,
          files: files,
          errors: errors,
          nextSteps: nextSteps,
        );
      }
    });
  }
}
