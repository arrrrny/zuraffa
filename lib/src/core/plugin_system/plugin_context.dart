import '../../models/generator_config.dart';
import '../context/file_system.dart';
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

  /// The file system abstraction.
  final FileSystem fileSystem;

  PluginContext({
    required this.core,
    required this.discovery,
    FileSystem? fileSystem,
    this.data = const {},
    Map<String, dynamic>? sharedData,
  }) : sharedData = sharedData ?? {},
       fileSystem = fileSystem ?? FileSystem.create(root: core.projectRoot);

  /// Gets a value from the plugin-specific data.
  ///
  /// Defensive against type collisions: returns `null` when the stored
  /// value isn't an instance of [T] instead of throwing a cast error.
  ///
  /// Some plugin ids share their name with a string-typed schema property
  /// of another plugin (notably `service` — `ServicePlugin.id == 'service'`
  /// collides with its own `configSchema.properties.service = {type:'string'}`
  /// and with `UseCasePlugin`'s same-named string property). The
  /// `PluginManager.buildContext` activation sync writes `data[id] = true`
  /// (bool) for active plugins so that downstream `data[id] == true`
  /// activation checks work — which poisons those string-typed slots.
  /// Hard-casting `data['service'] as String?` then throws
  /// `type 'bool' is not a subtype of type 'String?' in type cast`
  /// (issue #412). The defensive `is T` check returns `null` instead,
  /// letting the consumer fall back to its entity-derived default. The
  /// activation signal is still available via [isActive].
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// Returns `true` when [pluginId] is in the active-plugins set for this
  /// context.
  ///
  /// The activation sync in `PluginManager.buildContext` records active
  /// plugin ids under two keys: `data[pluginId] = true` for ids whose own
  /// schema doesn't claim the slot for a non-boolean type, and
  /// `data['__active_<pluginId>'] = true` for ids that DO collide (issue
  /// #412 — e.g. `service`). This helper checks both, so callers can query
  /// activation uniformly without knowing which bucket a given plugin id
  /// landed in.
  bool isActive(String pluginId) =>
      data[pluginId] == true || data['__active_$pluginId'] == true;

  /// Sets a value in the shared data.
  void setShared(String key, dynamic value) {
    sharedData[key] = value;
  }

  /// Gets a value from the shared data.
  ///
  /// Defensive against type collisions — see [get] for the rationale.
  T? getShared<T>(String key) {
    final value = sharedData[key];
    return value is T ? value : null;
  }
}
