import 'package:args/command_runner.dart';
import '../../commands/repository_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/create_repository_capability.dart';
import 'generators/implementation_generator.dart';
import 'generators/interface_generator.dart';

class RepositoryPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  late final RepositoryInterfaceGenerator interfaceGenerator;
  late final RepositoryImplementationGenerator implementationGenerator;

  RepositoryPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    interfaceGenerator = RepositoryInterfaceGenerator(
      outputDir: outputDir,
      options: options,
    );
    implementationGenerator = RepositoryImplementationGenerator(
      outputDir: outputDir,
      options: options,
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
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = RepositoryPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
      return delegator.generate(config);
    }

    final files = <GeneratedFile>[];
    if (config.isEntityBased) {
      files.add(await interfaceGenerator.generate(config));
    }
    if ((config.generateData || config.generateDataSource) &&
        !config.hasService) {
      files.add(await implementationGenerator.generate(config));
    }
    return files;
  }

  Future<GeneratedFile> generateInterface(GeneratorConfig config) {
    return interfaceGenerator.generate(config);
  }

  Future<GeneratedFile> generateImplementation(GeneratorConfig config) {
    return implementationGenerator.generate(config);
  }
}
