import 'package:args/command_runner.dart';
import '../../commands/repository_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/method_capability.dart';
import 'capabilities/create_repository_capability.dart';
import 'generators/implementation_generator.dart';
import 'generators/interface_generator.dart';

class RepositoryPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;

  late final RepositoryInterfaceGenerator interfaceGenerator;
  late final RepositoryImplementationGenerator implementationGenerator;
  final MethodAppendBuilder methodAppendBuilder;

  RepositoryPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MethodAppendBuilder? methodAppendBuilder,
  }) : methodAppendBuilder =
           methodAppendBuilder ??
           MethodAppendBuilder(outputDir: outputDir, options: options) {
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
    MethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'repository',
    ),
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
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'data': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate repository implementation',
      },
      'datasource': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate data source dependencies',
      },
      'use-service': {
        'type': 'boolean',
        'default': false,
        'description': 'Use service instead of repository',
      },
      'no-entity': {
        'type': 'boolean',
        'default': false,
        'description': 'Disable entity-based generation',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final useService = context.get<bool>('use-service') ?? false;
    if (useService) return [];

    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.get<bool>('no-entity') == true
              ? []
              : ['get', 'update', 'toggle']),
      domain: context.data['domain'],
      repo: context.data['repo'],
      paramsType: context.data['params'],
      returnsType: context.data['returns'],
      generateData: context.get<bool>('data') ?? context.data['data'] == true,
      generateDataSource:
          context.get<bool>('datasource') ?? context.data['datasource'] == true,
      enableCache: context.get<bool>('cache') ?? false,
      enableSync: context.get<bool>('sync') ?? false,
      syncDirection: context.get<String>('sync-direction') ?? 'push',
      generateLocal: context.get<bool>('local') ?? false,
      noEntity: context.get<bool>('no-entity') ?? false,
      useService: useService,
      generateRepository: true,
      appendToExisting:
          context.data['append'] == true ||
          context.data['method_append'] == true ||
          (context.get<bool>('no-entity') == true &&
              context.data['repo'] != null),
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (config.useService) return [];
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
      return delegator.generate(config, context: context);
    }

    final interfaceGen = context != null
        ? RepositoryInterfaceGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
            discovery: context.discovery,
          )
        : interfaceGenerator;

    final implementationGen = context != null
        ? RepositoryImplementationGenerator(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
            discovery: context.discovery,
          )
        : implementationGenerator;

    final files = <GeneratedFile>[];

    // If a repo is specified, we should target that repository instead of the config name
    var targetConfig = config;
    if (config.repo != null) {
      var repoBase = config.repo!;
      if (repoBase.endsWith('Repository')) {
        repoBase = repoBase.substring(0, repoBase.length - 10);
      }
      // Preserve the original name as the method name if it's a custom usecase
      final repoMethod = config.repoMethod ?? config.nameCamel;
      targetConfig = config.copyWith(name: repoBase, repoMethod: repoMethod);
    }

    if (config.isEntityBased ||
        (config.appendToExisting && config.repo != null)) {
      files.add(await interfaceGen.generate(targetConfig));
    }
    // #284: Always emit the data repository implementation alongside the
    // interface for entity-based configs.  Previously this was gated on
    // generateData || generateDataSource || appendToExisting, but those flags
    // are not reliably set when the make invocation activates the datasource
    // plugin via a preset (the schema default of false wins over the
    // plugin-activation sync in PluginManager.buildContext).  The DI plugin
    // unconditionally emits `product_repository_di.dart` referencing
    // `DataProductRepository` whenever generateRepository || generateData
    // is true, so the impl must be produced for every entity-based config to
    // keep the generated app compiling.
    if ((config.isEntityBased ||
            config.generateData ||
            config.generateDataSource ||
            config.appendToExisting) &&
        !config.hasService) {
      files.add(await implementationGen.generate(targetConfig));
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
