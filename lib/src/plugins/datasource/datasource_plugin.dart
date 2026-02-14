import 'package:args/command_runner.dart';
import '../../commands/datasource_command.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/interface_generator.dart';
import 'builders/local_generator.dart';
import 'builders/remote_generator.dart';

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
  Command createCommand() => DataSourceCommand(this);

  @override
  String get id => 'datasource';

  @override
  String get name => 'DataSource Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
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
      return delegator.generate(config);
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
}
