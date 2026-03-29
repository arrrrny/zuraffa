import '../../models/generator_config.dart';
import 'discovery_engine.dart';

/// Core configuration shared by all plugins.
class CoreConfig {
  /// The name of the entity or target to generate.
  final String name;

  /// The base project root.
  final String projectRoot;

  /// The base output directory (relative to project root).
  final String outputDir;

  /// Whether to perform a dry run (no disk writes).
  final bool dryRun;

  /// Whether to force overwrite existing files.
  final bool force;

  /// Whether to enable verbose logging.
  final bool verbose;

  /// Whether to revert the generation (delete/undo).
  final bool revert;

  const CoreConfig({
    required this.name,
    required this.projectRoot,
    this.outputDir = 'lib/src',
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    this.revert = false,
  });

  /// Temporary factory to bridge from the old [GeneratorConfig].
  factory CoreConfig.fromOld(GeneratorConfig config, {String? projectRoot}) {
    return CoreConfig(
      name: config.name,
      projectRoot: projectRoot ?? '',
      outputDir: config.outputDir,
      dryRun: config.dryRun,
      force: config.force,
      verbose: config.verbose,
      revert: config.revert,
    );
  }
}

/// A shared context providing configuration and shared data to plugins.
class PluginContext {
  /// The core configuration.
  final CoreConfig core;

  /// Plugin-specific data, validated against their schemas.
  final Map<String, dynamic> data;

  /// Shared data between plugins (e.g., paths of generated files).
  final Map<String, dynamic> sharedData;

  /// The engine for discovering existing files.
  final DiscoveryEngine discovery;

  PluginContext({
    required this.core,
    required this.discovery,
    this.data = const {},
    Map<String, dynamic>? sharedData,
  }) : sharedData = sharedData ?? {};

  /// Gets a value from the plugin-specific data.
  T? get<T>(String key) => data[key] as T?;

  /// Sets a value in the shared data.
  void setShared(String key, dynamic value) {
    sharedData[key] = value;
  }

  /// Gets a value from the shared data.
  T? getShared<T>(String key) => sharedData[key] as T?;
}
