import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'generators/interface_generator.dart';
import 'generators/implementation_generator.dart';

class RepositoryPlugin extends FileGeneratorPlugin {
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
  String get id => 'repository';

  @override
  String get name => 'Repository Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
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
