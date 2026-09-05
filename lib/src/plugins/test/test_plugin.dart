import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:path/path.dart' as path;

import '../../commands/test_command.dart';
import '../../core/ast/file_parser.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../core/project/test_receipt.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/test_builder.dart';
import 'capabilities/create_test_capability.dart';
import 'test_certifier.dart';

/// Manages unit test generation for domain and data layers.
class TestPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final TestBuilder testBuilder;
  final FileSystem fileSystem;

  /// Spec 980: self-certification runner (scoped `dart analyze` on every
  /// written test file). Injectable so tests can fake the analyzer.
  final TestSelfCertifier certifier;

  /// Machine verdict of the most recent real (non-dry-run) generation, or
  /// null when nothing was certified. Read by [TestCommand] / the create
  /// capability to fail non-compiling output.
  TestCertification? lastCertification;

  TestPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
    TestSelfCertifier? certifier,
  }) : certifier = certifier ?? TestSelfCertifier(),
       fileSystem = fileSystem ?? FileSystem.create() {
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
        // Spec 980: the delegated generation must self-certify through the
        // same (possibly injected) analyzer, not silently fall back.
        certifier: certifier,
      );
      final delegated = await delegator.generate(config, context: context);
      // Surface the delegated run's verdict on this plugin too, so the
      // command layer sees it without knowing about delegation.
      lastCertification = delegator.lastCertification;
      return delegated;
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
    final receiptEntries = <TestReceiptEntry>[];

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
        final file = await builder.generateForMethod(config, method);
        files.add(file);
        receiptEntries.addAll(_entityReceiptEntries(config, method, file));
      }
    }

    if (config.isOrchestrator) {
      final file = await builder.generateOrchestrator(config);
      files.add(file);
      if (file.action != 'skipped') {
        receiptEntries.add(
          _receiptEntry(
            name: 'should orchestrate all usecases',
            file: file,
            method: 'execute',
            acceptancePath: 'success',
            usecaseFile: _useCaseFileName(config.name),
          ),
        );
      }
    }

    if (config.isPolymorphic) {
      final variantFiles = await builder.generatePolymorphic(config);
      files.addAll(variantFiles);
      for (final file in variantFiles) {
        if (file.action == 'skipped') continue;
        final variantSnake = path
            .basenameWithoutExtension(path.basename(file.path))
            .replaceAll('_usecase_test', '');
        final usecaseFile = '${variantSnake}_usecase.dart';
        receiptEntries.add(
          _receiptEntry(
            name: config.useCaseType == 'stream'
                ? 'should emit values from stream'
                : 'should return Success',
            file: file,
            method: 'execute',
            acceptancePath: 'success',
            usecaseFile: usecaseFile,
          ),
        );
      }
    }

    if (config.isCustomUseCase &&
        !config.isPolymorphic &&
        !config.isOrchestrator) {
      final file = await builder.generateCustom(config);
      files.add(file);
      if (file.action != 'skipped') {
        receiptEntries.add(
          _receiptEntry(
            name: config.useCaseType == 'stream'
                ? 'should emit values from stream'
                : 'should return Success',
            file: file,
            method: 'execute',
            acceptancePath: 'success',
            usecaseFile: _useCaseFileName(config.name),
          ),
        );
      }
    }

    // Spec 980 — self-certification + per-method receipt, only for real
    // (non-dry-run, non-revert) runs that actually wrote test files.
    if (!config.dryRun && !config.revert && receiptEntries.isNotEmpty) {
      final projectRoot = _projectRoot();
      lastCertification = await certifier.certify(
        entity: config.name,
        projectRoot: projectRoot,
        files: files,
      );
      if (lastCertification != null) {
        print(lastCertification!.verdictLine);
      }
      await _writeTestReceipt(config, receiptEntries, projectRoot);
    }

    return files;
  }

  /// Project root convention shared with the test builders: the output
  /// directory is `<root>/lib/src`.
  String _projectRoot() => outputDir.replaceAll('lib/src', '');

  /// Use case file name (snake) for [name] without the `_usecase` suffix —
  /// e.g. `FetchUser` -> `fetch_user_usecase.dart`.
  String _useCaseFileName(String name) =>
      '${StringUtils.camelToSnake(name)}_usecase.dart';

  /// Receipt entries for one entity method's generated file: the success
  /// test and the failure test, both bound to that method's usecase
  /// source with digests of the exact bytes on disk.
  List<TestReceiptEntry> _entityReceiptEntries(
    GeneratorConfig config,
    String method,
    GeneratedFile file,
  ) {
    if (file.action == 'skipped' || file.content == null) return const [];
    final entitySnake = config.nameSnake;
    final String useCaseFileName;
    if (method == 'getList' || method == 'list') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }
    return [
      _receiptEntry(
        name: 'should call repository.$method and return result',
        file: file,
        method: method,
        acceptancePath: 'success',
        usecaseFile: useCaseFileName,
      ),
      _receiptEntry(
        name: 'should return Failure when repository throws',
        file: file,
        method: method,
        acceptancePath: 'failure',
        usecaseFile: useCaseFileName,
      ),
    ];
  }

  /// Builds one receipt entry, resolving the usecase file's real location
  /// through the plugin's [FileSystem] and digesting both artifacts.
  TestReceiptEntry _receiptEntry({
    required String name,
    required GeneratedFile file,
    required String method,
    required String acceptancePath,
    required String usecaseFile,
  }) {
    final testDigest = TestReceipt.digestOf(file.content ?? '');
    final usecasePath = _resolveUseCasePath(usecaseFile);
    final usecaseDigest = usecasePath == null
        ? null
        : TestReceipt.digestOf(_readOrEmpty(usecasePath));
    return TestReceiptEntry(
      name: name,
      testPath: _projectRelative(file.path),
      method: method,
      acceptancePath: acceptancePath,
      testSha256: testDigest,
      useCasePath: usecasePath,
      useCaseSha256: usecaseDigest,
    );
  }

  String _readOrEmpty(String projectRelativePath) {
    try {
      return fileSystem.readSync(
        path.join(_projectRoot(), projectRelativePath),
      );
    } catch (_) {
      return '';
    }
  }

  /// Finds [usecaseFile] under the output tree and returns its
  /// project-relative POSIX path (or null when not found).
  String? _resolveUseCasePath(String usecaseFile) {
    final root = _projectRoot();
    final candidates = fileSystem.listSync(
      path.join(outputDir, 'domain', 'usecases'),
      recursive: true,
    );
    for (final candidate in candidates) {
      if (path.basename(candidate) == usecaseFile) {
        return _projectRelative(candidate);
      }
    }
    // Fall back to the conventional location so the receipt still binds
    // the pair even when the file is created after generation.
    final conventional = path.join(
      'lib',
      'src',
      'domain',
      'usecases',
      usecaseFile,
    );
    return root.isEmpty && !fileSystem.existsSync(conventional)
        ? null
        : conventional;
  }

  /// Normalizes an (absolute or root-relative) path to project-relative
  /// POSIX form for receipt storage.
  String _projectRelative(String filePath) {
    final root = _projectRoot();
    final posixPath = filePath.replaceAll('\\', '/');
    if (root.isEmpty) {
      final normalized = path.posix.normalize(posixPath);
      if (!path.isAbsolute(normalized)) return normalized;
      // Relative output dir (the CLI case): `-C` made the project root
      // the process CWD, so absolutize against it to keep receipts
      // portable when the project tree moves.
      return path.posix
          .normalize(path.relative(normalized, from: Directory.current.path))
          .replaceAll('\\', '/');
    }
    if (path.isAbsolute(filePath) && !path.isAbsolute(root)) {
      return path.posix
          .normalize(path.relative(filePath, from: Directory.current.path))
          .replaceAll('\\', '/');
    }
    return path.posix
        .normalize(path.relative(filePath, from: root))
        .replaceAll('\\', '/');
  }

  /// Writes the per-entity `test.v1` receipt for this generation run.
  Future<void> _writeTestReceipt(
    GeneratorConfig config,
    List<TestReceiptEntry> entries,
    String projectRoot,
  ) async {
    final receipt = TestReceipt(
      entity: config.name,
      command: 'zfa test create --name ${config.name}',
      at: DateTime.now().toUtc(),
      tests: entries,
    );
    try {
      await TestReceiptStore(projectRoot: projectRoot).write(receipt);
    } catch (e) {
      // A receipt write failure must never mask a green generation, but
      // it is never silent either.
      print('  ⚠️  Failed to write test receipt for ${config.name}: $e');
    }
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
  ///
  /// Spec 980: uses the analyzer package AST (the established
  /// `FileParser`/`AstHelper` pattern used by the method_append builders)
  /// instead of regexes. Behavior-neutral on the existing fixtures: field
  /// declarations typed `XxxRepository` / `XxxService` / `XxxUseCase` feed
  /// repos/services/composed usecases exactly as the regex scan did; the
  /// target class's `extends` clause decides the usecase flavor. Unlike a
  /// text scan, local variables and comments can never masquerade as
  /// dependencies. Unparseable sources degrade to an empty analysis —
  /// there is deliberately no regex fallback.
  Map<String, dynamic> _parseUseCaseFile(
    String content,
    String className,
    String domain,
  ) {
    final parseResult = const FileParser().parseSource(content);
    final unit = parseResult.unit;

    final repos = <String>[];
    final services = <String>[];
    final composedUsecases = <String>[];

    if (unit != null) {
      for (final declaration in unit.declarations) {
        if (declaration is! ast.ClassDeclaration) continue;
        if (declaration.namePart.typeName.lexeme != className) continue;

        for (final member in declaration.body.members) {
          if (member is! ast.FieldDeclaration) continue;
          final declaredType = member.fields.type;
          if (declaredType == null) continue;
          // The regexes matched `final XxxRepository _x;` field
          // declarations; the AST reads the same declared type names,
          // generics stripped (`UseCase<User, NoParams>` -> `UseCase`).
          final typeName = declaredType.toSource().split('<').first.trim();
          if (typeName.endsWith('Repository') && typeName != 'Repository') {
            repos.add(typeName.substring(0, typeName.length - 10));
          } else if (typeName.endsWith('Service') && typeName != 'Service') {
            services.add(typeName.substring(0, typeName.length - 7));
          } else if (typeName.endsWith('UseCase') && typeName != 'UseCase') {
            composedUsecases.add(typeName.substring(0, typeName.length - 7));
          }
        }
      }
    }

    final isOrchestrator =
        composedUsecases.isNotEmpty && repos.isEmpty && services.isEmpty;

    final useCaseType = _resolveUseCaseType(unit, className);

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

  /// Determines the usecase flavor from the target class's `extends`
  /// superclass name — exact match, so `OsBackgroundTaskUseCase` never
  /// trips the `BackgroundUseCase` branch the way a substring scan could.
  String _resolveUseCaseType(ast.CompilationUnit? unit, String className) {
    if (unit == null) return 'usecase';
    for (final declaration in unit.declarations) {
      if (declaration is! ast.ClassDeclaration) continue;
      if (declaration.namePart.typeName.lexeme != className) continue;
      final superclass = declaration.extendsClause?.superclass;
      if (superclass == null) return 'usecase';
      final superName = superclass.toSource().split('<').first.trim();
      return switch (superName) {
        'StreamUseCase' => 'stream',
        'SyncUseCase' => 'sync',
        'OsBackgroundTaskUseCase' => 'os_background',
        'BackgroundUseCase' => 'background',
        _ => 'usecase',
      };
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
