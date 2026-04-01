import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/datasource_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
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
  }) : methodAppendBuilder =
           methodAppendBuilder ??
           MethodAppendBuilder(outputDir: outputDir, options: options),
       injectBuilder =
           injectBuilder ??
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
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'local': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate local data source',
      },
      'remote': {
        'type': 'boolean',
        'default': true,
        'description': 'Generate remote data source',
      },
      'cache': {
        'type': 'boolean',
        'default': false,
        'description': 'Enable caching dependencies',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      repo: context.data['repo'],
      generateDataSource: true,
      generateLocal: context.get<bool>('local') ?? false,
      generateRemote: context.get<bool>('remote') ?? true,
      enableCache: context.get<bool>('cache') ?? context.data['cache'] == true,
      useService:
          context.data['use-service'] == true ||
          context.data['useService'] == true,
      noEntity: context.data['no-entity'] == true,
      appendToExisting:
          context.data['append'] == true ||
          context.data['method_append'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
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
      return delegator.generate(config, context: context);
    }

    if (!(config.generateData ||
        config.generateDataSource ||
        config.appendToExisting)) {
      if (!config.revert) return [];
    }
    if (config.hasService) {
      return [];
    }

    final fs = context?.fileSystem ?? FileSystem.create(root: outputDir);

    final interfaceGen = context != null
        ? DataSourceInterfaceBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : interfaceGenerator;

    final remoteGen = context != null
        ? RemoteDataSourceBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : remoteGenerator;

    final localGen = context != null
        ? LocalDataSourceBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : localGenerator;

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

    final remoteExists = await fs.exists(remotePath);
    final localExists = await fs.exists(localPath);

    if (config.appendToExisting) {
      files.add(await interfaceGen.generate(config));

      if (remoteExists || config.generateRemote) {
        files.add(await remoteGen.generate(config));
      }

      if (localExists || config.generateLocal || config.enableCache) {
        files.add(await localGen.generate(config));
      }

      return files;
    }

    if (config.generateLocal || config.enableCache) {
      files.add(await localGen.generate(config));
    }

    if (config.generateRemote ||
        (config.enableCache && !config.generateLocal)) {
      files.add(await remoteGen.generate(config));
    }

    files.add(await interfaceGen.generate(config));

    return files;
  }
}
