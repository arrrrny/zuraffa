import 'package:args/command_runner.dart';
import '../../commands/cache_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/cache_builder.dart';
import 'capabilities/create_cache_capability.dart';

/// Manages Hive-based cache generation for the data layer.
///
/// Builds cache initialization, policy managers, and registrar helpers
/// to provide persistent storage and expiration logic for entities.
///
/// Example:
/// ```dart
/// final plugin = CachePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class CachePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final CacheBuilder cacheBuilder;

  CachePlugin({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ) {
    cacheBuilder = CacheBuilder(outputDir: outputDir, options: this.options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateCacheCapability(this)];

  @override
  Command createCommand() => CacheCommand(this);

  @override
  String get id => 'cache';

  @override
  String get name => 'Cache Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = CachePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
        ),
      );
      return delegator.generate(config);
    }

    if (!config.enableCache) {
      return [];
    }
    return cacheBuilder.generate(config);
  }
}
