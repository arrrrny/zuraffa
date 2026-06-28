import 'package:args/command_runner.dart';

import '../../commands/sync_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/sync_builder.dart';
import 'capabilities/create_sync_capability.dart';

/// Manages offline-first sync generation for the data layer.
///
/// Builds sync metadata box initialization, metadata store wrappers, and
/// sync strategy factories to provide push/bidirectional synchronization
/// for entities.
///
/// Example:
/// ```dart
/// final plugin = SyncPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product', enableSync: true));
/// ```
class SyncPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final SyncBuilder syncBuilder;

  SyncPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    syncBuilder = SyncBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateSyncCapability(this)];

  @override
  Command createCommand() => SyncCommand(this);

  @override
  String get id => 'sync';

  @override
  String get name => 'Sync Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => ['datasource', 'repository'];

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'sync-direction': {
        'type': 'string',
        'enum': ['push', 'bidirectional'],
        'default': 'push',
      },
      'sync-batch-size': {'type': 'integer', 'default': 50},
      'sync-max-retries': {'type': 'integer', 'default': 5},
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
      enableSync: true,
      syncDirection: context.get<String>('sync-direction') ?? 'push',
      syncBatchSize: context.get<int>('sync-batch-size') ?? 50,
      syncMaxRetries: context.get<int>('sync-max-retries') ?? 5,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableSync && !config.revert) {
      return [];
    }
    return syncBuilder.generate(config);
  }
}
