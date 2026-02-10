import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'generators/interface_generator.dart';
import 'generators/local_generator.dart';
import 'generators/remote_generator.dart';

class DataSourcePlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  late final DataSourceInterfaceGenerator interfaceGenerator;
  late final RemoteDataSourceGenerator remoteGenerator;
  late final LocalDataSourceGenerator localGenerator;

  DataSourcePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    interfaceGenerator = DataSourceInterfaceGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    remoteGenerator = RemoteDataSourceGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    localGenerator = LocalDataSourceGenerator(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  String get id => 'datasource';

  @override
  String get name => 'DataSource Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
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
}
