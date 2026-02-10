import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import 'service_generator.dart';
import 'provider_generator.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/di/di_plugin.dart';
import '../plugins/datasource/datasource_plugin.dart';
import 'state_generator.dart';
import 'observer_generator.dart';
import 'test_generator.dart';
import 'mock_generator.dart';
import '../core/generation/code_builder_factory.dart';
import '../core/generation/generation_context.dart';
import '../core/transaction/generation_transaction.dart';

class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final GenerationContext context;
  late final CodeBuilderFactory builderFactory;

  late final RepositoryPlugin _repositoryPlugin;
  late final ServiceGenerator _serviceGenerator;
  late final ProviderGenerator _providerGenerator;
  late final UseCasePlugin _useCasePlugin;
  late final ViewPlugin _viewPlugin;
  late final PresenterPlugin _presenterPlugin;
  late final ControllerPlugin _controllerPlugin;
  late final DiPlugin _diPlugin;
  late final DataSourcePlugin _dataSourcePlugin;
  late final StateGenerator _stateGenerator;
  late final ObserverGenerator _observerGenerator;
  late final TestGenerator _testGenerator;

  CodeGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  }) : context = GenerationContext.create(
         config: config,
         outputDir: outputDir,
         dryRun: dryRun,
         force: force,
         verbose: verbose,
         root: outputDir,
       ) {
    builderFactory = CodeBuilderFactory(context);
    _repositoryPlugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _serviceGenerator = builderFactory.service();
    _providerGenerator = builderFactory.provider();
    _useCasePlugin = UseCasePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _viewPlugin = ViewPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _presenterPlugin = PresenterPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _controllerPlugin = ControllerPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _diPlugin = DiPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _dataSourcePlugin = DataSourcePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _stateGenerator = builderFactory.state();
    _observerGenerator = builderFactory.observer();
    _testGenerator = builderFactory.test();
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
          errors.addAll(transactionResult.conflicts.map((c) => 'Conflict: $c'));
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
          final appender = builderFactory.methodAppender();
          final appendResult = await appender.appendMethod();

          final usecaseFiles = await _useCasePlugin.generate(config);
          files.addAll(usecaseFiles);

          files.addAll(appendResult.updatedFiles);

          if (appendResult.warnings.isNotEmpty) {
            nextSteps.addAll(appendResult.warnings.map((w) => '⚠️  $w'));
          }

          if (config.generateGql) {
            final graphqlGenerator = builderFactory.graphql();
            final graphqlFiles = await graphqlGenerator.generate();
            files.addAll(graphqlFiles);
          }

          return finalizeSuccess();
        }

        if (config.isEntityBased) {
          final repoFiles = await _repositoryPlugin.generate(config);
          files.addAll(repoFiles);

          final usecaseFiles = await _useCasePlugin.generate(config);
          files.addAll(usecaseFiles);
        } else if (config.isPolymorphic) {
          final usecaseFiles = await _useCasePlugin.generate(config);
          files.addAll(usecaseFiles);
        } else if (config.isOrchestrator) {
          final usecaseFiles = await _useCasePlugin.generate(config);
          files.addAll(usecaseFiles);
        } else if (config.isCustomUseCase) {
          if (config.hasService) {
            final serviceFile = await _serviceGenerator.generate();
            files.add(serviceFile);
          }
          final usecaseFiles = await _useCasePlugin.generate(config);
          files.addAll(usecaseFiles);
        }

        if (config.generateVpc || config.generatePresenter) {
          final presenterFiles = await _presenterPlugin.generate(config);
          files.addAll(presenterFiles);
        }

        if (config.generateVpc || config.generateController) {
          final controllerFiles = await _controllerPlugin.generate(config);
          files.addAll(controllerFiles);
        }

        if (config.generateVpc || config.generateView) {
          final viewFiles = await _viewPlugin.generate(config);
          files.addAll(viewFiles);
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
            final dataSourceFiles = await _dataSourcePlugin.generate(config);
            files.addAll(dataSourceFiles);

            final dataRepoFile = await _repositoryPlugin.generateImplementation(
              config,
            );
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
          final diFiles = await _diPlugin.generate(config);
          files.addAll(diFiles);
        }

        if (config.generateRoute) {
          final routeGenerator = builderFactory.route();
          final routeFiles = await routeGenerator.generate();
          files.addAll(routeFiles);
          nextSteps.add('Add go_router to your pubspec.yaml dependencies');
          nextSteps.add('Import routes from lib/src/routing/index.dart');
        }

        if (config.enableCache) {
          final cacheGenerator = builderFactory.cache();
          final cacheFiles = await cacheGenerator.generate();
          files.addAll(cacheFiles);
          nextSteps.add('Run: dart run build_runner build');
          nextSteps.add('Call initAllCaches() before DI setup');
        }

        if (config.generateGql) {
          final graphqlGenerator = builderFactory.graphql();
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
