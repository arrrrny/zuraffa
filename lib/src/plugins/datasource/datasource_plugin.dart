import 'package:args/command_runner.dart';
import '../../commands/datasource_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/interface_generator.dart';
import 'builders/local_generator.dart';
import 'builders/remote_generator.dart';
import 'capabilities/create_datasource_capability.dart';

import '../../core/plugin_system/plugin_action.dart';

class DataSourcePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final DataSourceInterfaceBuilder interfaceGenerator;
  late final RemoteDataSourceBuilder remoteGenerator;
  late final LocalDataSourceBuilder localGenerator;

  DataSourcePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    interfaceGenerator = DataSourceInterfaceBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    remoteGenerator = RemoteDataSourceBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    localGenerator = LocalDataSourceBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateDataSourceCapability(this),
      ];

  @override
  Command createCommand() => DataSourceCommand(this);

  @override
  String get id => 'datasource';

  @override
  String get name => 'DataSource Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> create(GeneratorConfig config) async {
    return _dispatch(config.copyWith(action: PluginAction.create));
  }

  @override
  Future<List<GeneratedFile>> delete(GeneratorConfig config) async {
    return _dispatch(config.copyWith(action: PluginAction.delete));
  }

  @override
  Future<List<GeneratedFile>> add(GeneratorConfig config) async {
    return _dispatch(config.copyWith(action: PluginAction.add));
  }

  @override
  Future<List<GeneratedFile>> remove(GeneratorConfig config) async {
    return _dispatch(config.copyWith(action: PluginAction.remove));
  }

  Future<List<GeneratedFile>> _dispatch(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = DataSourcePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      // Pass the action down
      return delegator._dispatch(config);
    }

    if (!(config.generateData || config.generateDataSource)) {
      return [];
    }
    if (config.hasService) {
      return [];
    }

    final files = <GeneratedFile>[];

    if (config.generateLocal) {
      files.add(await localGenerator.generate(config));
    } else {
      files.add(await remoteGenerator.generate(config));
    }

    if (config.enableCache && !config.generateLocal) {
      files.add(await localGenerator.generate(config));
    }

    files.add(await interfaceGenerator.generate(config));

    return files;
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    // Default generate calls dispatch with existing config action (default create)
    return _dispatch(config);
  }
}
