import 'dart:async';
import '../plugin_system/plugin_interface.dart';
import '../plugin_system/plugin_registry.dart';
import '../../models/generator_config.dart';
import '../../models/generated_file.dart';

/// Preset for common generation patterns.
class GenerationPreset {
  final String name;
  final String description;
  final List<String> plugins;
  final List<String> methods;

  const GenerationPreset({
    required this.name,
    required this.description,
    required this.plugins,
    this.methods = const ['get', 'getList', 'create', 'update', 'delete'],
  });

  static const entityCrud = GenerationPreset(
    name: 'entity-crud',
    description: 'Entity + Repository + UseCases for CRUD operations',
    plugins: ['repository', 'usecase'],
  );

  static const vpc = GenerationPreset(
    name: 'vpc',
    description: 'View + Presenter + Controller for presentation layer',
    plugins: ['view', 'presenter', 'controller'],
    methods: ['get', 'getList', 'create', 'update', 'delete'],
  );

  static const vpcWithState = GenerationPreset(
    name: 'vpc-state',
    description: 'VPC with State management',
    plugins: ['view', 'presenter', 'controller', 'state'],
  );

  static const fullStack = GenerationPreset(
    name: 'full-stack',
    description:
        'Complete feature: Repository, UseCases, VPC, DI, Routes, Tests',
    plugins: [
      'repository',
      'usecase',
      'view',
      'presenter',
      'controller',
      'di',
      'route',
      'test',
    ],
  );

  static const dataLayer = GenerationPreset(
    name: 'data-layer',
    description: 'Repository + DataSource for data layer',
    plugins: ['repository', 'datasource'],
  );

  static const all = [entityCrud, vpc, vpcWithState, fullStack, dataLayer];

  static GenerationPreset? byName(String name) {
    for (final preset in all) {
      if (preset.name == name) return preset;
    }
    return null;
  }
}

/// Result of orchestrated plugin generation.
class OrchestrationResult {
  final bool success;
  final List<GeneratedFile> files;
  final List<String> errors;
  final Map<String, List<GeneratedFile>> filesByPlugin;

  const OrchestrationResult({
    required this.success,
    this.files = const [],
    this.errors = const [],
    this.filesByPlugin = const {},
  });

  factory OrchestrationResult.success(
    Map<String, List<GeneratedFile>> filesByPlugin,
  ) {
    final allFiles = filesByPlugin.values.expand((f) => f).toList();
    return OrchestrationResult(
      success: true,
      files: allFiles,
      filesByPlugin: filesByPlugin,
    );
  }

  factory OrchestrationResult.failure(List<String> errors) {
    return OrchestrationResult(success: false, errors: errors);
  }
}

/// Orchestrates multiple plugins for coordinated generation.
class PluginOrchestrator {
  final PluginRegistry registry;
  final void Function(String)? logger;

  PluginOrchestrator({required this.registry, this.logger});

  void log(String message) {
    logger?.call(message);
  }

  /// Run generation using a preset.
  Future<OrchestrationResult> runPreset({
    required String presetName,
    required GeneratorConfig config,
  }) async {
    final preset = GenerationPreset.byName(presetName);
    if (preset == null) {
      return OrchestrationResult.failure(['Unknown preset: $presetName']);
    }

    final mergedConfig = GeneratorConfig(
      name: config.name,
      methods: config.methods.isNotEmpty ? config.methods : preset.methods,
      domain: config.domain,
      outputDir: config.outputDir,
      dryRun: config.dryRun,
      force: config.force,
      verbose: config.verbose,
    );

    return runPlugins(plugins: preset.plugins, config: mergedConfig);
  }

  /// Run specific plugins in order.
  Future<OrchestrationResult> runPlugins({
    required List<String> plugins,
    required GeneratorConfig config,
  }) async {
    final filesByPlugin = <String, List<GeneratedFile>>{};
    final errors = <String>[];

    log('🚀 Generating ${config.name}...');

    for (final pluginId in plugins) {
      final plugin = registry.getById(pluginId);
      if (plugin == null) {
        errors.add('Plugin not found: $pluginId');
        continue;
      }

      if (plugin is! FileGeneratorPlugin) {
        errors.add('Plugin $pluginId does not generate files');
        continue;
      }

      try {
        log('  ⚙️  ${plugin.name}...');
        final files = await plugin.generate(config);
        filesByPlugin[pluginId] = files;
        log('     ✅ ${files.length} files');
      } catch (e) {
        errors.add('$pluginId: $e');
        log('     ❌ Error: $e');
      }
    }

    if (errors.isNotEmpty && filesByPlugin.isEmpty) {
      return OrchestrationResult.failure(errors);
    }

    return OrchestrationResult.success(filesByPlugin);
  }

  /// Run all registered plugins that match the config.
  Future<OrchestrationResult> runAllMatching(GeneratorConfig config) async {
    final plugins = <String>[];

    // Repository: entity-based only (not for custom usecases without repo)
    if (config.isEntityBased) {
      plugins.add('repository');
    }
    if (config.generateRepository && !config.isEntityBased) {
      plugins.add('repository');
    }

    // UseCases: entity-based, or custom usecases (has useCaseType, params, or returns)
    if (config.isEntityBased ||
        config.methods.isNotEmpty ||
        config.useCaseType.isNotEmpty ||
        config.paramsType != null ||
        config.returnsType != null) {
      plugins.add('usecase');
    }

    if (config.generateData || config.generateDataSource) {
      plugins.add('datasource');
    }
    if (config.generateView) plugins.add('view');
    if (config.generatePresenter) plugins.add('presenter');
    if (config.generateController) plugins.add('controller');
    if (config.generateState) plugins.add('state');
    if (config.generateDi) plugins.add('di');
    if (config.generateRoute) plugins.add('route');
    if (config.generateTest) plugins.add('test');
    if (config.generateMock) plugins.add('mock');
    if (config.enableCache) plugins.add('cache');
    if (config.generateGql) plugins.add('graphql');
    if (config.generateObserver) plugins.add('observer');

    return runPlugins(plugins: plugins, config: config);
  }
}
