import 'package:args/command_runner.dart';
import '../../commands/cache_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
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
    this.options = const GeneratorOptions(),
  }) {
    cacheBuilder = CacheBuilder(outputDir: outputDir, options: options);
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
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'cache-policy': {
        'type': 'string',
        'enum': ['daily', 'restart', 'ttl'],
        'default': 'daily',
      },
      'ttl': {'type': 'integer', 'default': 1440},
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      enableCache: true,
      cachePolicy: context.get<String>('cache-policy') ?? 'daily',
      ttlMinutes: context.get<int>('ttl') ?? 1440,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableCache && !config.revert) {
      return [];
    }
    return cacheBuilder.generate(config);
  }
}
