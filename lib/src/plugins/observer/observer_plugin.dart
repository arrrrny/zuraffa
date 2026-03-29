import 'package:args/command_runner.dart';
import '../../commands/observer_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/observer_builder.dart';
import 'capabilities/create_observer_capability.dart';

/// Manages state observer generation.
///
/// Produces Flutter widgets or classes that observe and react to state changes,
/// often used for analytics or global UI reactions.
///
/// Example:
/// ```dart
/// final plugin = ObserverPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Auth'));
/// ```
class ObserverPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final ObserverBuilder observerBuilder;

  ObserverPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    observerBuilder = ObserverBuilder(outputDir: outputDir, options: options);
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

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateObserver && !config.revert) {
      return [];
    }
    final file = await observerBuilder.generate(config);
    return [file];
  }
}
