import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../commands/repository_command.dart';
import '../../core/context/file_system.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../version.dart' as cli_version;
import '../datasource/builders/interface_generator.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/method_capability.dart';
import 'capabilities/create_repository_capability.dart';
import 'conformance/repository_conformance_checker.dart';
import 'contract/repository_contract_manifest.dart';
import 'generators/implementation_generator.dart';
import 'generators/interface_generator.dart';
import 'plan/repository_emission_plan.dart';

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
    final config = configFromContext(context);
    return generate(config, context: context);
  }

  /// Builds the [GeneratorConfig] the plugin would run with, from the
  /// resolved [PluginContext] — the single source of truth shared by
  /// generation ([generateWithContext]) and explanation ([explainEmission]),
  /// so `--explain` can never drift from what generation actually does.
  static GeneratorConfig configFromContext(PluginContext context) {
    final useService = context.get<bool>('use-service') ?? false;

    return GeneratorConfig(
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
      // #294: read id-field / query-field from the CLI/MakeCommand-resolved
      // context so generators don't hardcode `EntityFields.id` for
      // entities whose id field is e.g. `depotId`.
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      useService: useService,
      generateRepository: true,
      appendToExisting:
          context.data['append'] == true ||
          context.data['method_append'] == true ||
          (context.get<bool>('no-entity') == true &&
              context.data['repo'] != null),
    );
  }

  /// Spec 0973: resolves the emission plan this plugin WOULD execute for
  /// [context] — what gets emitted, which variant, which flags triggered
  /// each decision. Used by `zfa make --explain` / `--json`; does not run
  /// generation and does not change PluginManager activation order.
  RepositoryEmissionPlan explainEmission(PluginContext context) {
    final config = configFromContext(context);
    final datasourceActive =
        context.data['datasource'] == true ||
        context.get<bool>('datasource') == true;
    return const RepositoryEmissionPlanner().resolve(
      config,
      datasourcePluginActive: datasourceActive,
    );
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
    // #284 / #348: Always emit the data repository implementation alongside
    // the interface for entity-based configs.  Historically this was gated
    // on generateData || generateDataSource || appendToExisting, but those
    // flags are not reliably set for `--append` runs that don't activate the
    // datasource plugin (the repository schema property `datasource` defaults
    // to false and only the active-plugin sync flips it to true).  #347 made
    // the plugin-activation sync run BEFORE the schema-default merge in
    // PluginManager.buildContext, so `data['datasource'] == true` now holds
    // whenever the datasource plugin is active (preset or explicit) and the
    // DI plugin emits `product_repository_di.dart` referencing
    // `DataProductRepository` whenever generateRepository || generateData
    // is true.  The impl is still produced unconditionally for every
    // entity-based config to keep `--append` and `--repo` flows compiling
    // even when no datasource plugin is active (custom-usecase scenarios).
    if ((config.isEntityBased ||
            config.generateData ||
            config.generateDataSource ||
            config.appendToExisting) &&
        !config.hasService) {
      files.add(await implementationGen.generate(targetConfig));
    }
    // #406: emit the data-source interface the implementation imports when
    // `--datasource` is requested. Previously `zfa repository create
    // --datasource` (default true) set `generateDataSource` but the
    // repository plugin never wrote the file, so the impl's
    // `import '../datasources/<entity>/<entity>_datasource.dart'` and its
    // `<Entity>DataSource _dataSource` field were unresolvable
    // (uri_does_not_exist + undefined_class). The DataSourcePlugin handles
    // this in the `zfa make` orchestrated flow (PluginManager activates it
    // and sets `data['datasource'] = true`); this covers the direct
    // `zfa repository create` path. We SKIP generation when the datasource
    // plugin is already active to avoid a "Multiple operations" conflict
    // on the same file. Generating only the interface (not local/remote)
    // matches exactly what the impl imports in the default (non-cache,
    // non-sync) branch of `_buildImportPaths`.
    final datasourcePluginActive =
        context != null &&
        (context.data['datasource'] == true ||
            context.get<bool>('datasource') == true);
    if (config.generateDataSource &&
        !config.hasService &&
        !datasourcePluginActive) {
      final datasourceInterfaceGen = context != null
          ? DataSourceInterfaceBuilder(
              outputDir: outputDir,
              options: options,
              fileSystem: context.fileSystem,
            )
          : DataSourceInterfaceBuilder(outputDir: outputDir, options: options);
      files.add(await datasourceInterfaceGen.generate(targetConfig));
    }

    // Spec 0973: prove the emitted interface↔impl pair conforms before the
    // run reports success. A mismatch fails the generation with `--> fix:`
    // naming the method and side (the CLI exits 1) instead of shipping a
    // pair that can only fail later at `zfa build`.
    await _runConformanceGate(files, targetConfig, context);

    return files;
  }

  /// Spec 0973: generation-time interface↔impl conformance gate.
  ///
  /// Runs only when this run emitted BOTH sides of the pair (created,
  /// overwritten or appended — skipped/deleted files are not this run's
  /// claim). Fresh pairs are audited in full; append flows are audited in
  /// delta scope: only the methods this run contributed, so hand-written
  /// members that predate the run cannot fail it.
  Future<void> _runConformanceGate(
    List<GeneratedFile> files,
    GeneratorConfig config,
    PluginContext? context,
  ) async {
    if (config.dryRun || config.revert) return;

    bool emitted(GeneratedFile f) =>
        f.action != 'skipped' &&
        f.action != 'deleted' &&
        f.action != 'reverted';

    final interfaceFile = files
        .where((f) => f.type == 'repository' && emitted(f))
        .toList();
    final implFile = files
        .where((f) => f.type == 'repository_implementation' && emitted(f))
        .toList();
    if (interfaceFile.isEmpty || implFile.isEmpty) return;

    final fs = context?.fileSystem ?? const DefaultFileSystem();
    final interfaceSource =
        interfaceFile.first.content ?? await fs.read(interfaceFile.first.path);
    final implSource =
        implFile.first.content ?? await fs.read(implFile.first.path);

    final freshPair =
        _isFreshEmit(interfaceFile.first.action) &&
        _isFreshEmit(implFile.first.action);
    final contributed = RepositoryConformanceChecker.contributedMethodNames(
      config,
    );

    final result = const RepositoryConformanceChecker().check(
      interfaceSource: interfaceSource,
      implementationSource: implSource,
      interfaceClassName: '${config.name}Repository',
      implementationClassName: 'Data${config.name}Repository',
      requiredInterfaceMethods: freshPair ? const {} : contributed,
      auditedImplementationMethods: freshPair ? const {} : contributed,
    );

    if (result.ok) {
      if (config.verbose) {
        print(
          '  ✓ repository conformance: ${result.interfaceMethods.length} '
          'interface method(s) ↔ ${result.implementationOverrides.length} '
          'override(s) — ${config.name}Repository ↔ '
          'Data${config.name}Repository',
        );
      }
      await _persistContractManifest(
        config: config,
        context: context,
        interfacePath: interfaceFile.first.path,
        interfaceSource: interfaceSource,
        implPath: implFile.first.path,
        implSource: implSource,
      );
      return;
    }

    print(
      '❌ Repository conformance gate failed for ${config.name} '
      '(${result.failures.length} mismatch(es)):',
    );
    for (final failure in result.failures) {
      print('  [${failure.side}] ${failure.message}');
      print('    ${failure.fix}');
    }
    throw RepositoryConformanceException(result);
  }

  bool _isFreshEmit(String action) =>
      action == 'created' || action == 'overwritten';

  /// Spec 0973: writes the per-entity repository contract manifest
  /// (`.zfa/receipts/repository-<entity>.json`) after the conformance gate
  /// passed — a manifest asserts "this pair conformed when it was written".
  /// Best-effort by design: the artifacts already exist, so a manifest
  /// failure degrades to a warning instead of failing the run.
  Future<void> _persistContractManifest({
    required GeneratorConfig config,
    required PluginContext? context,
    required String interfacePath,
    required String interfaceSource,
    required String implPath,
    required String implSource,
  }) async {
    try {
      final projectRoot = repositoryProjectRootFor(
        outputDir,
        explicitProjectRoot: context?.core.projectRoot,
      );
      final methods = const RepositoryContractExtractor().extract(
        interfaceSource: interfaceSource,
        className: '${config.name}Repository',
      );
      final manifest = RepositoryContractManifest(
        entity: config.name,
        interface: RepositoryContractFile(
          className: '${config.name}Repository',
          path: _projectRelativePosix(interfacePath, projectRoot),
          sha256: repositoryContractDigest(interfaceSource),
        ),
        implementation: RepositoryContractFile(
          className: 'Data${config.name}Repository',
          path: _projectRelativePosix(implPath, projectRoot),
          sha256: repositoryContractDigest(implSource),
        ),
        methods: methods,
        methodsSha256: RepositoryContractManifest.hashOfMethods(methods),
        generatorVersion: cli_version.version,
        at: DateTime.now().toUtc(),
      );
      await RepositoryContractManifestStore(
        projectRoot: projectRoot,
      ).save(manifest);
      if (config.verbose) {
        print(
          '  ✓ repository contract manifest: '
          '.zfa/receipts/repository-${config.nameSnake}.json',
        );
      }
    } catch (e) {
      print('⚠️  Repository contract manifest not written: $e');
    }
  }

  /// Normalizes a generated-file path to a project-relative POSIX path.
  String _projectRelativePosix(String filePath, String projectRoot) {
    final absolute = p.isAbsolute(filePath)
        ? filePath
        : p.join(p.absolute(projectRoot), filePath);
    final relative = p.relative(absolute, from: p.absolute(projectRoot));
    return p.normalize(relative).replaceAll('\\', '/');
  }

  Future<GeneratedFile> generateInterface(GeneratorConfig config) {
    return interfaceGenerator.generate(config);
  }

  Future<GeneratedFile> generateImplementation(GeneratorConfig config) {
    return implementationGenerator.generate(config);
  }
}
