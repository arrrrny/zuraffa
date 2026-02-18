import 'package:args/command_runner.dart';
import '../../commands/repository_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'generators/interface_generator.dart';
import 'generators/implementation_generator.dart';
import 'capabilities/create_repository_capability.dart';
import '../../core/plugin_system/capability.dart';

import '../../core/plugin_system/plugin_action.dart';

class RepositoryPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final RepositoryInterfaceGenerator interfaceGenerator;
  late final RepositoryImplementationGenerator implementationGenerator;

  RepositoryPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    interfaceGenerator = RepositoryInterfaceGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    implementationGenerator = RepositoryImplementationGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateRepositoryCapability(this),
      ];

  @override
  Command createCommand() => RepositoryCommand(this);

  @override
  String get id => 'repository';

  @override
  String get name => 'Repository Plugin';

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
      final delegator = RepositoryPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      // Pass the action down
      return delegator._dispatch(config);
    }

    final files = <GeneratedFile>[];
    // If deleting, we don't strictly need methods to identify the file path
    // But we need to ensure we have a name.
    final shouldRunInterface = config.isEntityBased ||
        (config.action == PluginAction.delete && config.name.isNotEmpty);

    if (shouldRunInterface) {
      files.add(await interfaceGenerator.generate(config));
    }
    if ((config.generateData || config.generateDataSource) &&
        !config.hasService) {
      files.add(await implementationGenerator.generate(config));
    }
    return files;
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    // Default generate calls dispatch with existing config action (default create)
    return _dispatch(config);
  }

  Future<GeneratedFile> generateInterface(GeneratorConfig config) {
    return interfaceGenerator.generate(config);
  }

  Future<GeneratedFile> generateImplementation(GeneratorConfig config) {
    return implementationGenerator.generate(config);
  }
}
