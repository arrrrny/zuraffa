import 'package:args/command_runner.dart';
import '../../commands/observer_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/observer_builder.dart';
import 'capabilities/create_observer_capability.dart';

/// Manages state observer generation.
class ObserverPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final ObserverBuilder observerBuilder;
  final FileSystem fileSystem;

  ObserverPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    observerBuilder = ObserverBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateObserverCapability(this)];

  @override
  Command createCommand() => ObserverCommand(this);

  @override
  String get id => 'observer';

  @override
  String get name => 'Observer Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateObserver: true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateObserver && !config.revert) {
      return [];
    }

    final builder = context != null
        ? ObserverBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : observerBuilder;

    final file = await builder.generate(config);
    return [file];
  }
}
