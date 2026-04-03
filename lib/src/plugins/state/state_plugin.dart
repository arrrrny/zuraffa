import 'package:args/command_runner.dart';
import '../../commands/state_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/state_builder.dart';
import 'capabilities/create_state_capability.dart';

/// Manages UI state class generation for the presentation layer.
class StatePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final StateBuilder stateBuilder;

  StatePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    stateBuilder = StateBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateStateCapability(this)];

  @override
  Command createCommand() => StateCommand(this);

  @override
  String get id => 'state';

  @override
  String get name => 'State Plugin';

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
      generateState: true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      noEntity: context.data['no-entity'] == true,
      domain: context.data['domain'],
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      paramsType: context.get<String>('params'),
      returnsType: context.get<String>('returns'),
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateState && !config.revert) {
      return [];
    }

    final builder = context != null
        ? StateBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : stateBuilder;

    final file = await builder.generate(config);
    return [file];
  }
}
