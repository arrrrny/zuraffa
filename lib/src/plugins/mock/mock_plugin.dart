import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../../commands/mock_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/entity_analyzer.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import '../method_append/builders/inject_builder.dart';
import '../method_append/builders/method_append_builder.dart';
import '../method_append/capabilities/inject_capability.dart';
import '../method_append/capabilities/method_capability.dart';
import '../di/builders/simulation_binding_builder.dart';
import 'builders/mock_builder.dart';
import 'capabilities/create_mock_capability.dart';
import 'capabilities/dependency_mock_capability.dart';
import 'capabilities/json_mock_capability.dart';

/// Manages mock data and provider generation for testing.
class MockPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final MockBuilder mockBuilder;
  final MethodAppendBuilder methodAppendBuilder;
  final InjectBuilder injectBuilder;
  final FileSystem fileSystem;

  MockPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MethodAppendBuilder? methodAppendBuilder,
    InjectBuilder? injectBuilder,
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(),
       methodAppendBuilder =
           methodAppendBuilder ??
           MethodAppendBuilder(outputDir: outputDir, options: options),
       injectBuilder =
           injectBuilder ??
           InjectBuilder(outputDir: outputDir, options: options) {
    mockBuilder = MockBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateMockCapability(this),
    DependencyMockCapability(this),
    JsonMockCapability(this),
    MethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'mock',
    ),
    InjectCapability(this, injectBuilder: injectBuilder, targetType: 'mock'),
  ];

  @override
  Command createCommand() => MockCommand(this);

  @override
  String get id => 'mock';

  @override
  String get name => 'Mock Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'mockByDefault';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'mock-data-only': {
        'type': 'boolean',
        'default': false,
        'description': 'Only generate mock data, not providers',
      },
      'mock-json': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate JSON mock data with fromJson-based helpers',
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
      // #294: default to the canonical CRUD method set used by the
      // di/usecase/test/state/controller/datasource/repository plugins
      // (['get', 'update', 'toggle']) so `--preset=crud --with=mock`
      // generates a fully-implemented mock datasource instead of an
      // empty class that fails `implements` with `non_abstract_class_inherits_abstract_member`.
      // Issue #1027: service mode conforms to the declared service
      // interface instead — the entity-CRUD default would crash there.
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.get<bool>('no-entity') == true ||
                  context.data['service'] != null
              ? []
              : ['get', 'update', 'toggle']),
      domain: context.data['domain'],
      repo: context.data['repo'],
      generateMock: true,
      generateMockDataOnly: context.get<bool>('mock-data-only') ?? false,
      generateMockJson: context.get<bool>('mock-json') ?? false,
      mockJsonDomain: context.data['mock-json-domain'],
      noEntity: context.data['no-entity'] == true,
      // #294: read id-field / query-field from the CLI/MakeCommand-resolved
      // context so generators don't hardcode `EntityFields.id` for
      // entities whose id field is e.g. `depotId`.
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      generateData: context.data['data'] == true,
      generateDataSource: context.data['datasource'] == true,
      generateRepository: context.data['repository'] == true,
      appendToExisting:
          context.data['append'] == true ||
          context.data['method_append'] == true,
      paramsType: context.data['params'],
      returnsType: context.data['returns'],
      useCaseType: context.data['type'] ?? 'usecase',
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateMock &&
        !config.generateMockDataOnly &&
        !config.revert) {
      return [];
    }
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = MockPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    if (config.noEntity) {
      return [];
    }

    final fs = context?.fileSystem ?? fileSystem;
    final builder = context != null
        ? MockBuilder(outputDir: outputDir, options: options, fileSystem: fs)
        : mockBuilder;

    // If mocks were explicitly requested, always generate/append.
    //
    // Issue #770: an explicit mock request must never be a silent no-op.
    // The stale presentation-only gate here returned [] when no data-layer
    // plugin was active — even though the user explicitly asked for mocks —
    // which made `zfa mock create --name X` (and the positional
    // `zfa mock X`) generate zero files while reporting success. The builder
    // itself is standalone-safe: #417 already made the mock-datasource path
    // emit the datasource interface it needs, and the data-only path has
    // always generated.
    if (config.generateMock || config.generateMockDataOnly) {
      final files = await builder.generate(config);

      // Spec 893 (T002, FR-002): `zfa mock create` generates the DI
      // registration for mocks — the simulation binding is emitted
      // alongside the mock datasource so the flavor is a first-class
      // output of the generation workflow, never hand-wired.
      if (config.generateMock &&
          !config.generateMockDataOnly &&
          !config.revert) {
        final entityName = config.repo != null
            ? config.repo!.replaceAll('Repository', '')
            : config.name;
        // Issue #1037: an enum entity has no CRUD datasource surface, so
        // it gets no simulation binding either — and the binding emitter
        // must not run for it. A pre-#1037 run may have left the
        // class-shaped artifacts on disk; purge them (generated-marker
        // files only) and rebuild the simulation index so one re-run
        // heals the tree.
        final isEnumEntity = EntityAnalyzer.isEnum(
          entityName,
          outputDir,
          fileSystem: fs,
        );
        if (isEnumEntity) {
          final purged = await _purgeEnumDatasourceArtifacts(entityName, fs);
          // The index must never outlive its bindings: a pre-#1037 run can
          // leave it importing this entity's binding even when the binding
          // file is already gone (a previous heal removed it), so the
          // stale-reference check runs independently of this run's purge
          // count (#1037).
          final healer = SimulationBindingEmitter(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
          );
          final indexPath = path.join(healer.simulationDir, 'index.dart');
          var indexReferencesEntity = false;
          if (await fs.exists(indexPath)) {
            try {
              indexReferencesEntity = (await fs.read(indexPath)).contains(
                '${StringUtils.camelToSnake(entityName)}'
                '_simulation_datasource_di.dart',
              );
            } catch (_) {
              indexReferencesEntity = false;
            }
          }
          if (purged.isNotEmpty || indexReferencesEntity) {
            final index = await healer.regenerateIndex(pendingFiles: const []);
            if (index != null) {
              files.add(index);
            } else {
              // Every binding is gone — regenerateIndex detects nothing
              // and returns null, so the stale index is rewritten as the
              // empty skeleton instead of being left behind (#1037).
              if (await fs.exists(indexPath)) {
                files.add(
                  await FileUtils.writeFile(
                    indexPath,
                    SimulationBindingEmitter.builder.buildIndexFile(
                      registrations: const [],
                    ),
                    'di_simulation_index',
                    force: true,
                    dryRun: options.dryRun,
                    verbose: options.verbose,
                    fileSystem: fs,
                  ),
                );
              }
            }
          }
        } else {
          final emitter = SimulationBindingEmitter(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
          );
          // Issue #1031: the simulation binding must follow the shape the
          // mock lane actually generated. Service mode emits
          // `<Name>Service` + `<Name>MockProvider` and never a datasource
          // pair, so it gets the service-shaped binding
          // (`<Name>Service` -> `<Name>MockProvider`); the datasource shape
          // (`<Entity>DataSource` -> `<Entity>MockDataSource`) stays
          // authoritative for the entity/datasource lane only.
          final serviceName = config.effectiveService;
          final serviceSnake = config.serviceSnake;
          final providerName = config.effectiveProvider;
          final GeneratedFile binding;
          if (config.hasService &&
              serviceName != null &&
              serviceSnake != null &&
              providerName != null) {
            // Mirror DiPlugin._generateServiceDI's import resolution:
            // prefer the domain-scoped service file when it exists on
            // disk, else the domain-less layout.
            final domainServicePath = path.join(
              outputDir,
              'domain',
              'services',
              config.effectiveDomain,
              '${serviceSnake}_service.dart',
            );
            final serviceImport = await fs.exists(domainServicePath)
                ? '../../domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
                : '../../domain/services/${serviceSnake}_service.dart';
            // MockProviderBuilder always writes the mock provider under
            // data/providers/<domain>/ in service mode (`hasService`).
            final mockProviderName = providerName.replaceAll(
              'Provider',
              'MockProvider',
            );
            final mockProviderSnake = StringUtils.camelToSnake(
              mockProviderName,
            );
            final mockProviderImport =
                '../../data/providers/${config.effectiveDomain}/$mockProviderSnake.dart';
            binding = await emitter.emitServiceBinding(
              serviceName: serviceName,
              mockProviderName: mockProviderName,
              serviceImport: serviceImport,
              mockProviderImport: mockProviderImport,
            );
          } else {
            binding = await emitter.emitBinding(entityName: entityName);
          }
          files.add(binding);
          final simulationIndex = await emitter.regenerateIndex(
            pendingFiles: [binding],
          );
          if (simulationIndex != null) {
            files.add(simulationIndex);
          }
          // Keep an existing app-level composition root wired with
          // `registerSimulationBindings(getIt);` (idempotent append).
          final mainIndex = await emitter.syncMainIndex();
          if (mainIndex != null) {
            files.add(mainIndex);
          }
        }
      }

      return files;
    }

    // If not explicitly requested, only run if we are appending to existing mocks
    if (config.appendToExisting) {
      final entityName = config.repo != null
          ? config.repo!.replaceAll('Repository', '')
          : config.name;
      final entitySnake = StringUtils.camelToSnake(entityName);
      final mockPath = path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_mock_datasource.dart',
      );

      final providerSnake = config.providerSnake;
      if (providerSnake != null) {
        final providerMockPath = path.join(
          outputDir,
          'data',
          'providers',
          config.effectiveDomain,
          '${providerSnake}_mock_provider.dart',
        );
        if (await fs.exists(providerMockPath)) {
          return builder.generate(config);
        }
      }

      if (await fs.exists(mockPath)) {
        return builder.generate(config);
      }
    }

    return [];
  }

  /// Issue #1037 self-heal: removes the class-shaped datasource artifacts a
  /// pre-#1037 run left on disk for an enum entity. Only files carrying the
  /// generated marker are deleted — a hand-written file in those paths is
  /// never touched. Returns the removed relative paths (for the honest log
  /// the caller prints).
  Future<List<String>> _purgeEnumDatasourceArtifacts(
    String entityName,
    FileSystem fs,
  ) async {
    const marker = '// GENERATED - DO NOT EDIT';
    final entitySnake = StringUtils.camelToSnake(entityName);
    final candidates = <String>[
      path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_datasource.dart',
      ),
      path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_mock_datasource.dart',
      ),
      path.join(
        outputDir,
        'di',
        'simulation',
        '${entitySnake}_simulation_datasource_di.dart',
      ),
    ];
    final purged = <String>[];
    for (final candidate in candidates) {
      if (!await fs.exists(candidate)) continue;
      try {
        final content = await fs.read(candidate);
        if (!content.contains(marker)) continue;
      } catch (_) {
        // Unreadable file in a generated path — leave it; the build gate
        // will name it if it is actually broken.
        continue;
      }
      await fs.delete(candidate);
      purged.add(candidate);
    }
    return purged;
  }
}
