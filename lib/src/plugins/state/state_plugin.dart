import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../../commands/state_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_action.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/state_builder.dart';
import 'capabilities/create_state_capability.dart';

class StatePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final StateBuilder stateBuilder;

  StatePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    stateBuilder = StateBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateStateCapability(this),
      ];

  @override
  Command createCommand() => StateCommand(this);

  @override
  String get id => 'state';

  @override
  String get name => 'State Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> create(GeneratorConfig config) =>
      _dispatch(config, PluginAction.create);

  @override
  Future<List<GeneratedFile>> delete(GeneratorConfig config) =>
      _dispatch(config, PluginAction.delete);

  @override
  Future<List<GeneratedFile>> add(GeneratorConfig config) =>
      _dispatch(config, PluginAction.add);

  @override
  Future<List<GeneratedFile>> remove(GeneratorConfig config) =>
      _dispatch(config, PluginAction.remove);

  Future<List<GeneratedFile>> _dispatch(
    GeneratorConfig config,
    PluginAction action,
  ) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = StatePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      return delegator._dispatch(config, action);
    }

    switch (action) {
      case PluginAction.create:
        return generate(config);
      case PluginAction.delete:
        return _delete(config);
      case PluginAction.add:
      case PluginAction.remove:
        // StatePlugin does not support adding/removing members dynamically yet.
        return [];
    }
  }

  Future<List<GeneratedFile>> _delete(GeneratorConfig config) async {
    final entitySnake = config.nameSnake;
    final fileName = '${entitySnake}_state.dart';
    final stateDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(stateDirPath, fileName);
    final file = File(filePath);

    if (!file.existsSync()) {
      return [];
    }

    if (!dryRun) {
      await file.delete();
    }

    return [
      GeneratedFile(path: filePath, type: 'state', action: 'deleted'),
    ];
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.generateState) {
      return [];
    }
    final file = await stateBuilder.generate(config);
    return [file];
  }
}
