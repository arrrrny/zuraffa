import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/test_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/test_builder.dart';
import 'capabilities/create_test_capability.dart';

/// Manages unit test generation for domain and data layers.
class TestPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final TestBuilder testBuilder;
  final FileSystem fileSystem;

  TestPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    testBuilder = TestBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateTestCapability(this)];

  @override
  Command createCommand() => TestCommand(this);

  @override
  String get id => 'test';

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'testByDefault';

  @override
  List<String> get runAfter => [
    'usecase',
    'repository',
    'service',
    'datasource',
    'provider',
    'view',
    'presenter',
    'controller',
    'di',
    'feature',
    'gql',
    'cache',
    'route',
    'shadcn',
  ];

  @override
  JsonSchema get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateTest: true,
      // #284: Apply the same entity-methods default the usecase/repository
      // plugins use, so the test plugin routes to generateForMethod (per-method
      // test files matching the per-method usecases) instead of generateCustom
      // which looks for a non-existent `product_usecase.dart`.
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.get<bool>('no-entity') == true
              ? []
              : ['get', 'update', 'toggle']),
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      variants: context.data['variants']?.cast<String>().toList() ?? [],
      noEntity: context.get<bool>('no-entity') ?? false,
      // #294: read id-field / query-field from the CLI/MakeCommand-resolved
      // context so generators don't hardcode `EntityFields.id` for
      // entities whose id field is e.g. `depotId`.
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      domain: context.get<String>('domain'),
      repo: context.get<String>('repo'),
      service: context.get<String>('service'),
      useService:
          context.data['use-service'] == true ||
          context.data['useService'] == true,
      generateData:
          context.data['data'] == true || context.data['generateData'] == true,
      generateDataSource:
          context.data['datasource'] == true ||
          context.data['generateDataSource'] == true,
      generateRepository:
          context.data['repository'] == true ||
          context.data['generateRepository'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateTest && !config.revert) {
      return [];
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = TestPlugin(
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

    final fs = context?.fileSystem ?? fileSystem;
    final builder = context != null
        ? TestBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
            discovery: context.discovery,
          )
        : testBuilder;

    // #508/#524: the id-neutral `--test`-only regeneration path (regenerating
    // tests for usecases that already exist, or a no-id entity whose implied
    // `usecase` plugin was dropped) must not silently skip usecase tests just
    // because the native-mock data layer was never generated. `test_builder_entity`
    // hard-requires those four artifacts and returns `action: 'skipped'` when any
    // is absent, which hides the gap. We emit a minimal native-mock placeholder
    // for any missing artifact here so the guard in `generateForMethod` passes and
    // the usecase test is actually written + compiled. This runs only when `--test`
    // is active and the entity is entity-based; a full CRUD+mock stack already has
    // these files, so it is a no-op there. (The `test_builder_test` "skips when
    // native mock missing" case calls `generateForMethod` directly, bypassing this
    // plugin, so that guard is intentionally preserved.)
    if (config.generateTest && config.isEntityBased) {
      await _ensureNativeMockInfra(config, fs);
    }

    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      final validMethods = [
        'get',
        'getList',
        'list',
        'create',
        'update',
        'delete',
        'toggle',
        'watch',
        'watchList',
      ];
      for (final method in config.methods) {
        if (!validMethods.contains(method)) continue;
        files.add(await builder.generateForMethod(config, method));
      }
    }

    if (config.isOrchestrator) {
      files.add(await builder.generateOrchestrator(config));
    }

    if (config.isPolymorphic) {
      files.addAll(await builder.generatePolymorphic(config));
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      files.add(await builder.generateCustom(config));
    }

    return files;
  }

  /// Builds a [GeneratorConfig] by inspecting the existing usecase source.
  Future<GeneratorConfig?> buildConfigFromUseCase(
    String name,
    String outputDir,
    String domain, {
    required bool dryRun,
    required bool force,
    required bool verbose,
    FileSystem? fs,
  }) async {
    final effectiveFs = fs ?? fileSystem;
    final analysis = await _analyzeUseCase(
      name,
      outputDir,
      domain,
      effectiveFs,
    );
    if (analysis == null) {
      return null;
    }

    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    String? repo;
    String? service;
    final usecases = <String>[];

    for (final r in analysis['repos'] as List<String>) {
      final repoName = '${r}Repository';
      repo ??= repoName;
    }

    for (final s in analysis['services'] as List<String>) {
      final serviceName = '${s}Service';
      service ??= serviceName;
    }

    if (analysis['isOrchestrator'] == true) {
      usecases.addAll(analysis['usecases'] as List<String>);
    }

    return GeneratorConfig(
      name: nameWithoutSuffix,
      domain: analysis['domain'] as String,
      usecases: usecases,
      repo: repo,
      service: service,
      useCaseType: analysis['useCaseType'] as String,
      generateTest: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      outputDir: outputDir,
    );
  }

  /// Locates and parses the usecase file to infer dependencies.
  Future<Map<String, dynamic>?> _analyzeUseCase(
    String name,
    String outputDir,
    String domain,
    FileSystem fs,
  ) async {
    final nameWithoutSuffix = name.replaceAll('UseCase', '');
    final useCaseSnake = StringUtils.camelToSnake(nameWithoutSuffix);
    final className = '${nameWithoutSuffix}UseCase';

    final domainDirPath = path.join(outputDir, 'domain', 'usecases', domain);
    if (await fs.exists(domainDirPath)) {
      final useCaseFile = path.join(
        domainDirPath,
        '${useCaseSnake}_usecase.dart',
      );

      if (await fs.exists(useCaseFile)) {
        final content = await fs.read(useCaseFile);
        return _parseUseCaseFile(content, className, domain);
      }
    }

    final usecasesDirPath = path.join(outputDir, 'domain', 'usecases');
    if (await fs.exists(usecasesDirPath)) {
      final items = await fs.list(usecasesDirPath);
      for (final item in items) {
        if (await fs.isDirectory(item)) {
          final foundDomain = path.basename(item);
          final useCaseFile = path.join(item, '${useCaseSnake}_usecase.dart');

          if (await fs.exists(useCaseFile)) {
            final content = await fs.read(useCaseFile);
            return _parseUseCaseFile(content, className, foundDomain);
          }
        }
      }
    }

    return null;
  }

  /// Parses a usecase file to extract dependencies and type metadata.
  Map<String, dynamic> _parseUseCaseFile(
    String content,
    String className,
    String domain,
  ) {
    final repoMatches = RegExp(
      r'final\s+(\w+)Repository\s+(\w+)',
    ).allMatches(content);
    final repos = repoMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    final serviceMatches = RegExp(
      r'final\s+(\w+)Service\s+(\w+)',
    ).allMatches(content);
    final services = serviceMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .toList();

    final usecaseMatches = RegExp(
      r'final\s+(\w+UseCase)\s+_(\w+)',
    ).allMatches(content);
    final composedUsecases = usecaseMatches
        .map((m) {
          final className = m.group(1);
          if (className == null) return null;
          return className.endsWith('UseCase')
              ? className.substring(0, className.length - 7)
              : className;
        })
        .whereType<String>()
        .toList();

    final isOrchestrator =
        composedUsecases.isNotEmpty && repos.isEmpty && services.isEmpty;

    final useCaseType = _resolveUseCaseType(content);

    return {
      'className': className,
      'repos': repos,
      'services': services,
      'usecases': composedUsecases,
      'domain': domain,
      'isOrchestrator': isOrchestrator,
      'useCaseType': useCaseType,
    };
  }

  /// Determines usecase flavor based on inheritance in the source.
  String _resolveUseCaseType(String content) {
    if (content.contains('StreamUseCase')) {
      return 'stream';
    }
    if (content.contains('SyncUseCase')) {
      return 'sync';
    }
    if (content.contains('OsBackgroundTaskUseCase')) {
      return 'os_background';
    }
    if (content.contains('BackgroundUseCase')) {
      return 'background';
    }
    return 'usecase';
  }

  /// Ensures the four native-mock artifacts the per-method test builder requires
  /// (`{entity}_datasource.dart`, `{entity}_mock_datasource.dart`,
  /// `{entity}_mock_data.dart`, `data_{entity}_repository.dart`) exist before
  /// usecase tests are regenerated. Any that are missing are written as minimal
  /// placeholders so the id-neutral `--test`-only path stays green instead of
  /// silently skipping. Safe to call when the artifacts are already present
  /// (e.g. after `--mock`): those are left untouched.
  Future<void> _ensureNativeMockInfra(
    GeneratorConfig config,
    FileSystem fs,
  ) async {
    final entitySnake = StringUtils.camelToSnake(config.name);
    final needed = <String, String>{
      '${entitySnake}_datasource.dart': path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_datasource.dart',
      ),
      '${entitySnake}_mock_datasource.dart': path.join(
        outputDir,
        'data',
        'datasources',
        entitySnake,
        '${entitySnake}_mock_datasource.dart',
      ),
      '${entitySnake}_mock_data.dart': path.join(
        outputDir,
        'data',
        'mock',
        '${entitySnake}_mock_data.dart',
      ),
      'data_${entitySnake}_repository.dart': path.join(
        outputDir,
        'domain',
        'repositories',
        'data_${entitySnake}_repository.dart',
      ),
    };

    for (final entry in needed.entries) {
      if (await fs.exists(entry.value)) continue;
      await FileUtils.writeFile(
        entry.value,
        _nativeMockPlaceholder(config.name, entitySnake, entry.key),
        'mock',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fs,
      );
    }
  }

  /// Builds a minimal, syntactically-valid native-mock placeholder for a single
  /// missing artifact. The real CRUD+mock generators produce the fully-wired
  /// versions; this only exists so the id-neutral `--test`-only path can write a
  /// compilable usecase test when the full data layer was never generated.
  String _nativeMockPlaceholder(
    String entityName,
    String entitySnake,
    String fileName,
  ) {
    final header =
        '// GENERATED BY ZFA — placeholder native-mock artifact.\n'
        '// Emitted by the test plugin on the id-neutral `--test`-only path\n'
        '// when the full CRUD+mock stack was not generated first.\n';
    if (fileName == '${entitySnake}_datasource.dart') {
      return '$header\nabstract class ${entityName}DataSource {}\n';
    }
    if (fileName == '${entitySnake}_mock_datasource.dart') {
      return '$header\nclass ${entityName}MockDataSource '
          'implements ${entityName}DataSource {}\n';
    }
    if (fileName == '${entitySnake}_mock_data.dart') {
      return '$header\nclass ${entityName}MockData {\n'
          '  static dynamic sample$entityName = null;\n}\n';
    }
    // data_<snake>_repository.dart
    return '$header\nclass Data${entityName}Repository {\n'
        '  Data${entityName}Repository(dynamic dataSource);\n}\n';
  }
}
