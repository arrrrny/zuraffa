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
import '../method_append/builders/inject_builder.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/inject_capability.dart';
import '../method_append/capabilities/method_capability.dart';
import '../method_append/capabilities/private_method_capability.dart';
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
  final MethodAppendBuilder methodAppendBuilder;
  final InjectBuilder injectBuilder;

  DataSourcePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MethodAppendBuilder? methodAppendBuilder,
    InjectBuilder? injectBuilder,
  }) : methodAppendBuilder = methodAppendBuilder ??
            MethodAppendBuilder(outputDir: outputDir, options: options),
       injectBuilder = injectBuilder ??
            InjectBuilder(outputDir: outputDir, options: options) {
    interfaceGenerator = DataSourceInterfaceBuilder(
      outputDir: outputDir,
      options: options,
    );
    remoteGenerator = RemoteDataSourceBuilder(
      outputDir: outputDir,
      options: options,
    );
    localGenerator = LocalDataSourceBuilder(
      outputDir: outputDir,
      options: options,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateDataSourceCapability(this),
        MethodCapability(
          this,
          methodAppendBuilder: methodAppendBuilder,
          targetType: 'datasource',
        ),
        PrivateMethodCapability(
          this,
          methodAppendBuilder: methodAppendBuilder,
          targetType: 'datasource',
        ),
        InjectCapability(
          this,
          injectBuilder: injectBuilder,
          targetType: 'datasource',
        ),
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
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = DataSourcePlugin(
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

    if (!(config.generateData ||
        config.generateDataSource ||
        config.appendToExisting)) {
      return [];
    }
    if (config.hasService) {
      return [];
    }

    final files = <GeneratedFile>[];

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
    final localPath = path.join(
      outputDir,
      'data',
      'datasources',
      repoSnake,
      '${repoSnake}_local_datasource.dart',
    );

    final remoteExists = File(remotePath).existsSync();
    final localExists = File(localPath).existsSync();

    if (config.appendToExisting) {
      files.add(await interfaceGenerator.generate(config));

      if (remoteExists || config.generateRemote) {
        files.add(await remoteGenerator.generate(config));
      }

      if (localExists || config.generateLocal || config.enableCache) {
        files.add(await localGenerator.generate(config));
      }

      return files;
    }

    if (config.generateLocal || config.enableCache) {
      files.add(await localGenerator.generate(config));
    }

    if (config.generateRemote ||
        (config.enableCache && !config.generateLocal)) {
      // If we already generated local due to enableCache, we still want remote
      files.add(await remoteGenerator.generate(config));
    }

    files.add(await interfaceGenerator.generate(config));

    return files;
  }
}
