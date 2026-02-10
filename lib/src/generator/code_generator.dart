import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import 'provider_generator.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/di/di_plugin.dart';
import '../plugins/datasource/datasource_plugin.dart';
import '../plugins/service/service_plugin.dart';
import 'state_generator.dart';
import 'observer_generator.dart';
import 'test_generator.dart';
import 'mock_generator.dart';
import '../core/generation/code_builder_factory.dart';
import '../core/generation/generation_context.dart';
import '../core/transaction/generation_transaction.dart';
import '../core/context/progress_reporter.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';

class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final Set<String> disabledPlugins;
  final GenerationContext context;
  late final CodeBuilderFactory builderFactory;
  late final PluginRegistry pluginRegistry;

  late final RepositoryPlugin _repositoryPlugin;
  late final ProviderGenerator _providerGenerator;
  late final UseCasePlugin _useCasePlugin;
  late final ViewPlugin _viewPlugin;
  late final PresenterPlugin _presenterPlugin;
  late final ControllerPlugin _controllerPlugin;
  late final DiPlugin _diPlugin;
  late final DataSourcePlugin _dataSourcePlugin;
  late final ServicePlugin _servicePlugin;
  late final StateGenerator _stateGenerator;
  late final ObserverGenerator _observerGenerator;
  late final TestGenerator _testGenerator;

  CodeGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    ProgressReporter? progressReporter,
    Set<String>? disabledPluginIds,
  }) : context = GenerationContext.create(
         config: config,
         outputDir: outputDir,
         dryRun: dryRun,
         force: force,
         verbose: verbose,
         root: outputDir,
         progressReporter: progressReporter,
       ),
       disabledPlugins = disabledPluginIds ?? {} {
    builderFactory = CodeBuilderFactory(context);
    pluginRegistry = PluginRegistry();
    _repositoryPlugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
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
    _servicePlugin = ServicePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _stateGenerator = builderFactory.state();
    _observerGenerator = builderFactory.observer();
    _testGenerator = builderFactory.test();

    _registerPlugin(_repositoryPlugin);
    _registerPlugin(_useCasePlugin);
    _registerPlugin(_viewPlugin);
    _registerPlugin(_presenterPlugin);
    _registerPlugin(_controllerPlugin);
    _registerPlugin(_diPlugin);
    _registerPlugin(_dataSourcePlugin);
    _registerPlugin(_servicePlugin);
  }

  Future<GeneratorResult> generate() async {
    final transaction = GenerationTransaction(dryRun: dryRun);

    return GenerationTransaction.run(transaction, () async {
      final progress = context.progress;
      final files = <GeneratedFile>[];
      final errors = <String>[];
      final nextSteps = <String>[];
      String? currentPluginId;

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
        final validation = await pluginRegistry.validateAll(config);
        if (!validation.isValid) {
          errors.addAll(validation.reasons);
          if (validation.message != null) {
            errors.add(validation.message!);
          }
          progress.failed('Validation failed');
          return GeneratorResult(
            name: config.name,
            success: false,
            files: files,
            errors: errors,
            nextSteps: nextSteps,
          );
        }

        final totalSteps = _countSteps(config);
        if (totalSteps > 0) {
          progress.started('Generating ${config.name}', totalSteps);
        }
        await pluginRegistry.beforeGenerateAll(config);

        if (config.appendToExisting) {
          final appender = builderFactory.methodAppender();
          final appendResult = await appender.appendMethod();

          if (_isPluginEnabled('usecase')) {
            progress.update('usecase');
            currentPluginId = 'usecase';
            final usecaseFiles = await _useCasePlugin.generate(config);
            files.addAll(usecaseFiles);
            currentPluginId = null;
          }

          files.addAll(appendResult.updatedFiles);

          if (appendResult.warnings.isNotEmpty) {
            nextSteps.addAll(appendResult.warnings.map((w) => '⚠️  $w'));
          }

          if (config.generateGql) {
            progress.update('graphql');
            final graphqlGenerator = builderFactory.graphql();
            final graphqlFiles = await graphqlGenerator.generate();
            files.addAll(graphqlFiles);
          }

          await pluginRegistry.afterGenerateAll(config);
          progress.completed();
          return finalizeSuccess();
        }

        if (config.isEntityBased) {
          if (_isPluginEnabled('repository')) {
            progress.update('repository');
            currentPluginId = 'repository';
            final repoFiles = await _repositoryPlugin.generate(config);
            files.addAll(repoFiles);
            currentPluginId = null;
          }

          if (_isPluginEnabled('usecase')) {
            progress.update('usecase');
            currentPluginId = 'usecase';
            final usecaseFiles = await _useCasePlugin.generate(config);
            files.addAll(usecaseFiles);
            currentPluginId = null;
          }
        } else if (config.isPolymorphic) {
          if (_isPluginEnabled('usecase')) {
            progress.update('usecase');
            currentPluginId = 'usecase';
            final usecaseFiles = await _useCasePlugin.generate(config);
            files.addAll(usecaseFiles);
            currentPluginId = null;
          }
        } else if (config.isOrchestrator) {
          if (_isPluginEnabled('usecase')) {
            progress.update('usecase');
            currentPluginId = 'usecase';
            final usecaseFiles = await _useCasePlugin.generate(config);
            files.addAll(usecaseFiles);
            currentPluginId = null;
          }
        } else if (config.isCustomUseCase) {
          if (config.hasService && _isPluginEnabled('service')) {
            progress.update('service');
            currentPluginId = 'service';
            final serviceFiles = await _servicePlugin.generate(config);
            files.addAll(serviceFiles);
            currentPluginId = null;
          }
          if (_isPluginEnabled('usecase')) {
            progress.update('usecase');
            currentPluginId = 'usecase';
            final usecaseFiles = await _useCasePlugin.generate(config);
            files.addAll(usecaseFiles);
            currentPluginId = null;
          }
        }

        if (config.generateVpc || config.generatePresenter) {
          if (_isPluginEnabled('presenter')) {
            progress.update('presenter');
            currentPluginId = 'presenter';
            final presenterFiles = await _presenterPlugin.generate(config);
            files.addAll(presenterFiles);
            currentPluginId = null;
          }
        }

        if (config.generateVpc || config.generateController) {
          if (_isPluginEnabled('controller')) {
            progress.update('controller');
            currentPluginId = 'controller';
            final controllerFiles = await _controllerPlugin.generate(config);
            files.addAll(controllerFiles);
            currentPluginId = null;
          }
        }

        if (config.generateVpc || config.generateView) {
          if (_isPluginEnabled('view')) {
            progress.update('view');
            currentPluginId = 'view';
            final viewFiles = await _viewPlugin.generate(config);
            files.addAll(viewFiles);
            currentPluginId = null;
          }
        }

        if (config.generateState) {
          progress.update('state');
          final file = await _stateGenerator.generate();
          files.add(file);
        }

        if (config.generateObserver) {
          progress.update('observer');
          final file = await _observerGenerator.generate();
          files.add(file);
        }

        if (config.generateData || config.generateDataSource) {
          if (config.hasService && config.generateData) {
            progress.update('provider');
            final providerFile = await _providerGenerator.generate();
            files.add(providerFile);
            nextSteps.add(
              'Implement ${config.effectiveProvider} with external service client',
            );
          } else {
            if (_isPluginEnabled('datasource')) {
              progress.update('datasource');
              currentPluginId = 'datasource';
              final dataSourceFiles = await _dataSourcePlugin.generate(config);
              files.addAll(dataSourceFiles);
              currentPluginId = null;
            }

            if (!config.isEntityBased) {
              if (_isPluginEnabled('repository')) {
                progress.update('repository');
                currentPluginId = 'repository';
                final dataRepoFile = await _repositoryPlugin
                    .generateImplementation(config);
                files.add(dataRepoFile);
                currentPluginId = null;
              }
            }
          }
        }

        if (config.generateMock || config.generateMockDataOnly) {
          progress.update('mock');
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
            progress.update('test');
            final testFile = await _testGenerator.generateForMethod(method);
            files.add(testFile);
          }
          nextSteps.add('Run tests: flutter test ');
        }

        if (config.generateTest && config.isOrchestrator) {
          progress.update('test');
          final testFile = await _testGenerator.generateOrchestrator();
          files.add(testFile);
          nextSteps.add('Run tests: flutter test ');
        }

        if (config.generateTest && config.isPolymorphic) {
          progress.update('test');
          final testFiles = await _testGenerator.generatePolymorphic();
          files.addAll(testFiles);
          nextSteps.add('Run tests: flutter test ');
        }

        if (config.generateTest &&
            config.isCustomUseCase &&
            !config.isPolymorphic &&
            !config.isOrchestrator) {
          progress.update('test');
          final testFile = await _testGenerator.generateCustom();
          files.add(testFile);
          nextSteps.add('Run tests: flutter test ');
        }

        if (config.generateDi) {
          if (_isPluginEnabled('di')) {
            progress.update('di');
            currentPluginId = 'di';
            final diFiles = await _diPlugin.generate(config);
            files.addAll(diFiles);
            currentPluginId = null;
          }
        }

        if (config.generateRoute) {
          progress.update('route');
          final routeGenerator = builderFactory.route();
          final routeFiles = await routeGenerator.generate();
          files.addAll(routeFiles);
          nextSteps.add('Add go_router to your pubspec.yaml dependencies');
          nextSteps.add('Import routes from lib/src/routing/index.dart');
        }

        if (config.enableCache) {
          progress.update('cache');
          final cacheGenerator = builderFactory.cache();
          final cacheFiles = await cacheGenerator.generate();
          files.addAll(cacheFiles);
          nextSteps.add('Run: dart run build_runner build');
          nextSteps.add('Call initAllCaches() before DI setup');
        }

        if (config.generateGql) {
          progress.update('graphql');
          final graphqlGenerator = builderFactory.graphql();
          final graphqlFiles = await graphqlGenerator.generate();
          files.addAll(graphqlFiles);
        }

        await pluginRegistry.afterGenerateAll(config);
        progress.completed();
        return finalizeSuccess();
      } catch (e, stack) {
        if (currentPluginId != null) {
          errors.add('Plugin $currentPluginId failed: $e');
        } else {
          errors.add('Generation failed: $e');
        }
        await pluginRegistry.onErrorAll(config, e, stack);
        if (verbose) {
          errors.add('Stack trace:\n$stack');
        }
        progress.failed(e.toString());
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

  void _registerPlugin(ZuraffaPlugin plugin) {
    if (!disabledPlugins.contains(plugin.id)) {
      pluginRegistry.register(plugin);
    }
  }

  bool _isPluginEnabled(String id) {
    return pluginRegistry.getById(id) != null;
  }

  int _countSteps(GeneratorConfig config) {
    var steps = 0;
    if (config.appendToExisting) {
      steps += 1;
      if (_isPluginEnabled('usecase')) steps += 1;
      if (config.generateGql) steps += 1;
      return steps;
    }
    if (config.isEntityBased) {
      if (_isPluginEnabled('repository')) steps += 1;
      if (_isPluginEnabled('usecase')) steps += 1;
    } else if (config.isPolymorphic || config.isOrchestrator) {
      if (_isPluginEnabled('usecase')) steps += 1;
    } else if (config.isCustomUseCase) {
      if (config.hasService && _isPluginEnabled('service')) steps += 1;
      if (_isPluginEnabled('usecase')) steps += 1;
    }
    if (config.generateVpc || config.generatePresenter) {
      if (_isPluginEnabled('presenter')) steps += 1;
    }
    if (config.generateVpc || config.generateController) {
      if (_isPluginEnabled('controller')) steps += 1;
    }
    if (config.generateVpc || config.generateView) {
      if (_isPluginEnabled('view')) steps += 1;
    }
    if (config.generateState) steps += 1;
    if (config.generateObserver) steps += 1;
    if (config.generateData || config.generateDataSource) {
      if (config.hasService && config.generateData) {
        steps += 1;
      } else {
        if (_isPluginEnabled('datasource')) steps += 1;
        if (!config.isEntityBased && _isPluginEnabled('repository')) steps += 1;
      }
    }
    if (config.generateMock || config.generateMockDataOnly) steps += 1;
    if (config.generateTest) {
      steps += config.methods.isEmpty ? 1 : config.methods.length;
    }
    if (config.generateDi && _isPluginEnabled('di')) steps += 1;
    if (config.generateRoute) steps += 1;
    if (config.enableCache) steps += 1;
    if (config.generateGql) steps += 1;
    return steps;
  }
}
