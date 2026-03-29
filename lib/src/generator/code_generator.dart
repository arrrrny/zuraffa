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
import '../core/generator_options.dart';
import '../core/generation/generation_context.dart';
import '../core/transaction/generation_transaction.dart';
import '../core/context/progress_reporter.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_context.dart';
import '../core/plugin_system/discovery_engine.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plan_store.dart';
import '../core/plugin_system/capability.dart';

/// Orchestrates the entire code generation process.
///
/// Coordinates multiple plugins, manages transactions, and provides progress
/// reporting during the generation lifecycle.
///
/// Example:
/// ```dart
/// final generator = CodeGenerator(
///   config: config,
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final result = await generator.generate();
/// ```
class CodeGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final GeneratorOptions options;
  final Set<String> disabledPlugins;
  final GenerationContext context;
  late final PluginRegistry pluginRegistry;
  late final PluginContext pluginContext;

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
         root: outputDir,
         progressReporter: progressReporter,
       ),
       disabledPlugins = disabledPluginIds ?? {} {
    pluginRegistry = PluginRegistry();
    final discovery = DiscoveryEngine(projectRoot: outputDir);
    pluginContext = PluginContext(
      core: CoreConfig(
        name: config.name,
        projectRoot: outputDir,
        outputDir: outputDir,
        dryRun: options.dryRun,
        force: options.force,
        verbose: options.verbose,
        revert: options.revert,
      ),
      discovery: discovery,
      data: config.toJson(),
    );

    // Legacy registration of all plugins to keep existing behavior
    // while moving to the new system.
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
    _registerPlugin(GraphqlPlugin(outputDir: outputDir, options: options));
    _registerPlugin(CachePlugin(outputDir: outputDir, options: options));
    _registerPlugin(RoutePlugin(outputDir: outputDir, options: options));
    _registerPlugin(
      MethodAppendPlugin(outputDir: outputDir, options: options),
    );
  }

  Future<GeneratorResult> generate() async {
    final manager = PluginManager(registry: pluginRegistry);

    try {
      final activePlugins = pluginRegistry.plugins;
      final files = await manager.run(
        pluginContext,
        activePlugins,
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

  List<String> _buildNextSteps(GeneratorConfig config, List<GeneratedFile> files) {
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

  bool _isPluginEnabled(String id) {
    return pluginRegistry.getById(id) != null;
  }
}
