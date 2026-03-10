import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/datasource_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';
import 'builders/interface_generator.dart';
import 'builders/local_generator.dart';
import 'builders/remote_generator.dart';
import 'capabilities/create_datasource_capability.dart';

/// Manages data source generation for the data layer.
///
/// Coordinates interface, remote, and local data source generators to build
/// implementation classes for data access.
///
/// Example:
/// ```dart
/// final plugin = DataSourcePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class DataSourcePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  late final DataSourceInterfaceBuilder interfaceGenerator;
  late final RemoteDataSourceBuilder remoteGenerator;
  late final LocalDataSourceBuilder localGenerator;

  DataSourcePlugin({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ) {
    interfaceGenerator = DataSourceInterfaceBuilder(
      outputDir: outputDir,
      options: this.options,
    );
    remoteGenerator = RemoteDataSourceBuilder(
      outputDir: outputDir,
      options: this.options,
    );
    localGenerator = LocalDataSourceBuilder(
      outputDir: outputDir,
      options: this.options,
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
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = DataSourcePlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
        ),
      );
      return delegator.generate(config);
    }

    if (!(config.generateData ||
        config.generateDataSource ||
        config.appendToExisting)) {
      return [];
    }
    if (config.hasService) {
      return [];
    }

    final files = <GeneratedFile>[];

    if (config.appendToExisting) {
      files.add(await interfaceGenerator.generate(config));

      final repoBase = config.repo ?? config.name;
      final repoName = repoBase.endsWith('Repository')
          ? repoBase.replaceAll('Repository', '')
          : repoBase;
      final repoSnake = StringUtils.camelToSnake(repoName);

      final remotePath = path.join(
        outputDir,
        'data',
        'datasources',
        repoSnake,
        '${repoSnake}_remote_datasource.dart',
      );
      if (File(remotePath).existsSync()) {
        files.add(await remoteGenerator.generate(config));
      }

      final localPath = path.join(
        outputDir,
        'data',
        'datasources',
        repoSnake,
        '${repoSnake}_local_datasource.dart',
      );
      if (File(localPath).existsSync()) {
        files.add(await localGenerator.generate(config));
      }

      return files;
    }

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
