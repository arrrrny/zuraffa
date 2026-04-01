import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capability.dart';
import 'plugin_lifecycle.dart';
import 'plugin_context.dart';

/// Base interface for all Zuraffa plugins.
abstract class ZuraffaPlugin {
  /// Unique identifier for the plugin (e.g., 'usecase', 'di').
  String get id;

  /// Human-readable name of the plugin.
  String get name;

  /// Semantic version of the plugin.
  String get version;

  /// List of plugin IDs that must run BEFORE this plugin.
  List<String> get dependsOn => [];

  /// List of plugin IDs that this plugin should run AFTER, if they are present.
  /// (Like dependsOn, but doesn't force the other plugin to be active).
  List<String> get runAfter => [];

  /// JSON Schema for this plugin's configuration.
  ///
  /// Used for CLI argument generation and validation.
  JsonSchema get configSchema => {};

  /// The key in .zfa.json that enables this plugin by default (e.g., 'diByDefault').
  String? get configKey => null;

  /// List of capabilities exposed by this plugin.
  List<ZuraffaCapability> get capabilities => [];

  /// Validates the plugin configuration against the [context].
  Future<ValidationResult> validate(PluginContext context) async {
    return ValidationResult.success();
  }

  /// Hook called before generation starts.
  Future<void> beforeGenerate(PluginContext context) async {}

  /// Hook called after generation completes successfully.
  Future<void> afterGenerate(PluginContext context) async {}

  /// Hook called if an error occurs during generation.
  Future<void> onError(
    PluginContext context,
    Object error,
    StackTrace stackTrace,
  ) async {}

  // --- Legacy Compatibility ---

  /// Legacy validation method.
  @Deprecated('Use validate(PluginContext) instead')
  Future<ValidationResult> validateLegacy(GeneratorConfig config) async {
    return ValidationResult.success();
  }
}

/// A plugin that generates files.
abstract class FileGeneratorPlugin extends ZuraffaPlugin {
  /// Generates files based on the provided [context].
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    // Default implementation bridges back to legacy generate by mapping context data
    final config = GeneratorConfig.fromJson(context.data, context.core.name);
    // Ensure core flags are respected even if not in data map
    final finalConfig = config.copyWith(
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      outputDir: context.core.outputDir,
    );
    return await generate(finalConfig);
  }

  /// Legacy generation method for backward compatibility.
  Future<List<GeneratedFile>> generate(GeneratorConfig config);
}
