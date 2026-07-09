import 'package:args/command_runner.dart';

import '../../core/context/file_system.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import '../../commands/api_command.dart';
import 'builders/api_bridge_builder.dart';
import 'capabilities/create_api_bridge_capability.dart';

/// Generates VM Service extension bridges for Zuraffa entities.
///
/// Each bridge file exposes every UseCase of a target entity as a
/// `dart:developer` extension (`ext.zuraffa.<domain>.<usecase>`).
///
/// Usage: `zfa api Product`
class ApiPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;
  late final ApiBridgeBuilder _builder;

  ApiPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    _builder = ApiBridgeBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  String get id => 'api';

  @override
  String get name => 'API Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<ZuraffaCapability> get capabilities => [CreateApiBridgeCapability(this)];

  @override
  Command<void> createCommand() => ApiCommand(this);

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final entityName = context.core.name;
    final domain =
        context.data['domain'] as String? ??
        StringUtils.camelToSnake(entityName);

    final config = GeneratorConfig(
      name: entityName,
      outputDir: context.core.outputDir,
      domain: domain,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
    );
    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    final fs = context?.fileSystem ?? fileSystem;
    final builder = context != null
        ? ApiBridgeBuilder(
            outputDir: config.outputDir,
            options: options,
            fileSystem: fs,
          )
        : _builder;
    return builder.generate(config);
  }
}
