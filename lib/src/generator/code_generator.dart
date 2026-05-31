import 'dart:io';

import 'package:path/path.dart' as path;

import '../cli/plugin_loader.dart';
import '../config/zfa_config.dart';
import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import '../plugins/provider/provider_plugin.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/observer/observer_plugin.dart';
import '../plugins/test/test_plugin.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/graphql/graphql_plugin.dart';
import '../plugins/gql/gql_plugin.dart';
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
import '../plugins/shadcn/shadcn_plugin.dart';
import '../core/generator_options.dart';
import '../core/generation/generation_context.dart';
import '../core/context/progress_reporter.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_context.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/planning/generation_plan.dart';

/// Orchestrates the entire code generation process.
///
/// Coordinates multiple plugins, manages transactions, and provides progress
/// reporting during the generation lifecycle.
class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final GeneratorOptions options;
  final Set<String> disabledPlugins;
  final GenerationContext context;
  final String projectRoot;
  late final PluginRegistry pluginRegistry;
  late final PluginManager _manager;

  CodeGenerator({
    required GeneratorConfig config,
    required this.outputDir,
    this.options = const GeneratorOptions(),
    ProgressReporter? progressReporter,
    Set<String>? disabledPluginIds,
  }) : config = config.copyWith(
         outputDir: outputDir,
         dryRun: options.dryRun,
         force: options.force,
         verbose: options.verbose,
         revert: options.revert,
       ),
       context = GenerationContext.create(
         config: config.copyWith(
           outputDir: outputDir,
           dryRun: options.dryRun,
           force: options.force,
           verbose: options.verbose,
           revert: options.revert,
         ),
         outputDir: outputDir,
         dryRun: options.dryRun,
         force: options.force,
         verbose: options.verbose,
         root: _findProjectRoot(outputDir),
         progressReporter: progressReporter,
       ),
       disabledPlugins = disabledPluginIds ?? {},
       projectRoot = _findProjectRoot(outputDir) {
    pluginRegistry = PluginRegistry();

    // Register all core plugins
    _registerPlugin(RepositoryPlugin(outputDir: outputDir, options: options));
    _registerPlugin(ProviderPlugin(outputDir: outputDir, options: options));
    _registerPlugin(UseCasePlugin(outputDir: outputDir, options: options));
    _registerPlugin(ViewPlugin(outputDir: outputDir, options: options));
    _registerPlugin(PresenterPlugin(outputDir: outputDir, options: options));
    _registerPlugin(ControllerPlugin(outputDir: outputDir, options: options));
    _registerPlugin(DiPlugin(outputDir: outputDir, options: options));
    _registerPlugin(DataSourcePlugin(outputDir: outputDir, options: options));
    _registerPlugin(ServicePlugin(outputDir: outputDir, options: options));
    _registerPlugin(StatePlugin(outputDir: outputDir, options: options));
    _registerPlugin(ObserverPlugin(outputDir: outputDir, options: options));
    _registerPlugin(TestPlugin(outputDir: outputDir, options: options));
    _registerPlugin(MockPlugin(outputDir: outputDir, options: options));
    _registerPlugin(GqlPlugin(outputDir: outputDir, options: options));
    _registerPlugin(GraphqlPlugin(outputDir: outputDir, options: options));
    _registerPlugin(CachePlugin(outputDir: outputDir, options: options));
    _registerPlugin(RoutePlugin(outputDir: outputDir, options: options));
    _registerPlugin(ShadcnPlugin(outputDir: outputDir, options: options));
    _registerPlugin(MethodAppendPlugin(outputDir: outputDir, options: options));

    final loadedConfig = ZfaConfig.load(projectRoot: projectRoot);
    final loadedPluginConfig = PluginConfig.load(projectRoot: projectRoot);
    _manager = PluginManager(
      registry: pluginRegistry,
      config: loadedConfig,
      pluginConfig: PluginConfig(
        disabled: {...loadedPluginConfig.disabled, ...disabledPlugins},
      ),
      projectRoot: projectRoot,
    );
  }

  GenerationPlan resolvePlan() {
    final data = Map<String, dynamic>.from(config.toJson());
    if (data['methods'] is List) {
      data['methods'] = List<String>.from(data['methods'] as List);
    }
    return _manager.resolvePlan(name: config.name, options: data);
  }

  Future<GeneratorResult> generate() async {
    try {
      // Resolve the same normalized plan contract used by the CLI.
      final data = Map<String, dynamic>.from(config.toJson());
      if (data['methods'] is List) {
        data['methods'] = List<String>.from(data['methods'] as List);
      }

      final plan = _manager.resolvePlan(name: config.name, options: data);

      // Build context using manager to ensure TransactionalFileSystem is set up.
      final baseContext = _manager.buildContext(
        name: config.name,
        argResults: null,
        activePlugins: plan.activePlugins,
        overrideOutputDir: outputDir,
      );

      final pluginContext = PluginContext(
        core: CoreConfig(
          name: config.name,
          projectRoot: outputDir,
          outputDir: outputDir,
          dryRun: options.dryRun,
          force: options.force,
          verbose: options.verbose,
          revert: options.revert,
        ),
        discovery: baseContext.discovery,
        fileSystem: baseContext.fileSystem,
        data: data,
      );

      // Ensure specific flags are respected in data map as well
      pluginContext.data['append'] = config.appendToExisting;

      final files = await _manager.run(
        pluginContext,
        plan.activePlugins,
        progress: context.progress,
      );

      return GeneratorResult(
        name: config.name,
        success: true,
        files: files,
        errors: [],
        nextSteps: _buildNextSteps(config, files),
      );
    } catch (e, stack) {
      if (options.verbose) {
        print('Generation error: $e');
        print('Stack trace:\n$stack');
      }
      context.progress.failed(e.toString());
      return GeneratorResult(
        name: config.name,
        success: false,
        files: [],
        errors: [e.toString()],
        nextSteps: [],
      );
    }
  }

  List<String> _buildNextSteps(
    GeneratorConfig config,
    List<GeneratedFile> files,
  ) {
    final nextSteps = <String>[];
    if (config.generateData) {
      nextSteps.add(
        'Implement ${config.effectiveProvider} with external service client',
      );
    }
    if (config.generateRepository && config.isEntityBased) {
      nextSteps.add('Implement Data${config.name}Repository in data layer');
    }
    if (config.effectiveRepos.isNotEmpty) {
      nextSteps.add('Register repositories with DI container');
    }
    if (files.any((f) => f.type == 'usecase' && (!config.isEntityBased))) {
      nextSteps.add('Implement TODO sections in generated usecases');
    }
    if (config.enableCache) {
      nextSteps.add('Run: zfa build');
      nextSteps.add('Call initAllCaches() before DI setup');
    }
    return nextSteps;
  }

  void _registerPlugin(ZuraffaPlugin plugin) {
    if (!disabledPlugins.contains(plugin.id)) {
      pluginRegistry.register(plugin);
    }
  }

  static String _findProjectRoot(String startPath) {
    var current = Directory(path.normalize(startPath)).absolute;
    if (!current.existsSync()) {
      current = current.parent;
    }

    while (true) {
      if (File(path.join(current.path, 'pubspec.yaml')).existsSync()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        return Directory(path.normalize(startPath)).absolute.path;
      }
      current = parent;
    }
  }
}
