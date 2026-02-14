import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import '../plugins/provider/provider_plugin.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/observer/observer_plugin.dart';
import '../plugins/test/test_plugin.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/graphql/graphql_plugin.dart';
import '../plugins/cache/cache_plugin.dart';
import '../plugins/route/route_plugin.dart';
import '../plugins/method_append/method_append_plugin.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/view/view_plugin.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/di/di_plugin.dart';
import '../plugins/datasource/datasource_plugin.dart';
import '../plugins/service/service_plugin.dart';
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
  late final PluginRegistry pluginRegistry;

  late final RepositoryPlugin _repositoryPlugin;
  late final ProviderPlugin _providerPlugin;
  late final UseCasePlugin _useCasePlugin;
  late final ViewPlugin _viewPlugin;
  late final PresenterPlugin _presenterPlugin;
  late final ControllerPlugin _controllerPlugin;
  late final DiPlugin _diPlugin;
  late final DataSourcePlugin _dataSourcePlugin;
  late final ServicePlugin _servicePlugin;
  late final StatePlugin _statePlugin;
  late final ObserverPlugin _observerPlugin;
  late final TestPlugin _testPlugin;
  late final MockPlugin _mockPlugin;
  late final GraphqlPlugin _graphqlPlugin;
  late final CachePlugin _cachePlugin;
  late final RoutePlugin _routePlugin;
  late final MethodAppendPlugin _methodAppendPlugin;

  CodeGenerator({
    required GeneratorConfig config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    ProgressReporter? progressReporter,
    Set<String>? disabledPluginIds,
  }) : config = config.copyWith(outputDir: outputDir),
       context = GenerationContext.create(
         config: config.copyWith(outputDir: outputDir),
         outputDir: outputDir,
         dryRun: dryRun,
         force: force,
         verbose: verbose,
         root: outputDir,
         progressReporter: progressReporter,
       ),
       disabledPlugins = disabledPluginIds ?? {} {
    pluginRegistry = PluginRegistry();
    _repositoryPlugin = RepositoryPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _providerPlugin = ProviderPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
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
    _statePlugin = StatePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _observerPlugin = ObserverPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _testPlugin = TestPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _mockPlugin = MockPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _graphqlPlugin = GraphqlPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _cachePlugin = CachePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _routePlugin = RoutePlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    _methodAppendPlugin = MethodAppendPlugin(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    _registerPlugin(_repositoryPlugin);
    _registerPlugin(_providerPlugin);
    _registerPlugin(_useCasePlugin);
    _registerPlugin(_viewPlugin);
    _registerPlugin(_presenterPlugin);
    _registerPlugin(_controllerPlugin);
    _registerPlugin(_diPlugin);
    _registerPlugin(_dataSourcePlugin);
    _registerPlugin(_servicePlugin);
    _registerPlugin(_statePlugin);
    _registerPlugin(_observerPlugin);
    _registerPlugin(_testPlugin);
    _registerPlugin(_mockPlugin);
    _registerPlugin(_graphqlPlugin);
    _registerPlugin(_cachePlugin);
    _registerPlugin(_routePlugin);
    _registerPlugin(_methodAppendPlugin);
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
          final appendResult = await _methodAppendPlugin.appendMethod(config);

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
            if (_isPluginEnabled('graphql')) {
              progress.update('graphql');
              currentPluginId = 'graphql';
              final graphqlFiles = await _graphqlPlugin.generate(config);
              files.addAll(graphqlFiles);
              currentPluginId = null;
            }
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

        if (config.generateState && _isPluginEnabled('state')) {
          progress.update('state');
          currentPluginId = 'state';
          final stateFiles = await _statePlugin.generate(config);
          files.addAll(stateFiles);
          currentPluginId = null;
        }

        if (config.generateObserver && _isPluginEnabled('observer')) {
          progress.update('observer');
          currentPluginId = 'observer';
          final observerFiles = await _observerPlugin.generate(config);
          files.addAll(observerFiles);
          currentPluginId = null;
        }

        if (config.generateData || config.generateDataSource) {
          if (config.hasService && config.generateData) {
            if (_isPluginEnabled('provider')) {
              progress.update('provider');
              currentPluginId = 'provider';
              final providerFiles = await _providerPlugin.generate(config);
              files.addAll(providerFiles);
              currentPluginId = null;
            }
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

        if ((config.generateMock || config.generateMockDataOnly) &&
            _isPluginEnabled('mock')) {
          progress.update('mock');
          currentPluginId = 'mock';
          final mockFiles = await _mockPlugin.generate(config);
          files.addAll(mockFiles);
          currentPluginId = null;

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
            config.isEntityBased &&
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

        if (config.generateTest && _isPluginEnabled('test')) {
          progress.update('test');
          currentPluginId = 'test';
          final testFiles = await _testPlugin.generate(config);
          files.addAll(testFiles);
          currentPluginId = null;
          if (testFiles.isNotEmpty) {
            nextSteps.add('Run tests: flutter test ');
          }
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

        if (config.generateRoute && _isPluginEnabled('route')) {
          progress.update('route');
          currentPluginId = 'route';
          final routeFiles = await _routePlugin.generate(config);
          files.addAll(routeFiles);
          currentPluginId = null;
          nextSteps.add('Add go_router to your pubspec.yaml dependencies');
          nextSteps.add('Import routes from lib/src/routing/index.dart');
        }

        if (config.enableCache && _isPluginEnabled('cache')) {
          progress.update('cache');
          currentPluginId = 'cache';
          final cacheFiles = await _cachePlugin.generate(config);
          files.addAll(cacheFiles);
          currentPluginId = null;
          nextSteps.add('Run: dart run build_runner build');
          nextSteps.add('Call initAllCaches() before DI setup');
        }

        if (config.generateGql && _isPluginEnabled('graphql')) {
          progress.update('graphql');
          currentPluginId = 'graphql';
          final graphqlFiles = await _graphqlPlugin.generate(config);
          files.addAll(graphqlFiles);
          currentPluginId = null;
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
        if (verbose) {
          print('Generation error: $e');
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
    if (config.generateState && _isPluginEnabled('state')) steps += 1;
    if (config.generateObserver && _isPluginEnabled('observer')) steps += 1;
    if (config.generateData || config.generateDataSource) {
      if (config.hasService && config.generateData) {
        if (_isPluginEnabled('provider')) steps += 1;
      } else {
        if (_isPluginEnabled('datasource')) steps += 1;
        if (!config.isEntityBased && _isPluginEnabled('repository')) steps += 1;
      }
    }
    if ((config.generateMock || config.generateMockDataOnly) &&
        _isPluginEnabled('mock')) {
      steps += 1;
    }
    if (config.generateTest && _isPluginEnabled('test')) {
      steps += 1;
    }
    if (config.generateDi && _isPluginEnabled('di')) steps += 1;
    if (config.generateRoute && _isPluginEnabled('route')) steps += 1;
    if (config.enableCache && _isPluginEnabled('cache')) steps += 1;
    if (config.generateGql && _isPluginEnabled('graphql')) steps += 1;
    return steps;
  }
}
