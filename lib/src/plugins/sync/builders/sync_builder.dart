import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates offline-first sync support files.
///
/// Produces three categories of files for each sync-enabled entity:
///
/// 1. **Sync init** (`sync/{entity_snake}_sync.dart`): Opens the Hive box
///    for `SyncMetadata` records.
/// 2. **Metadata store wrapper** (`data/datasources/{entity_snake}/{entity_snake}_sync_metadata_store.dart`):
///    Wraps the Hive box in a `SyncMetadataStore` instance.
/// 3. **Strategy factory** (`data/datasources/{entity_snake}/{entity_snake}_sync_strategy.dart`):
///    Creates a `PushOnlySyncStrategy` or `BidirectionalSyncStrategy` wired to
///    the entity's local/remote datasources.
///
/// Also maintains a `sync/index.dart` barrel file that aggregates all sync
/// init calls (parallel to `cache/index.dart`).
class SyncBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final FileSystem fileSystem;

  SyncBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create();

  /// Generates sync support files for the given [config].
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableSync) {
      return [];
    }

    final files = <GeneratedFile>[];
    files.add(await _generateSyncInitFile(config));
    files.add(await _generateSyncMetadataStoreFile(config));
    files.add(await _generateSyncStrategyFile(config));
    await _regenerateSyncIndex(config);
    return files;
  }

  /// Generates `sync/{entity_snake}_sync.dart`.
  ///
  /// Opens the Hive box for SyncMetadata:
  /// ```dart
  /// Future<void> init{Entity}Sync() async {
  ///   await Hive.openBox<SyncMetadata>('sync_metadata_{entity_snake}');
  /// }
  /// ```
  Future<GeneratedFile> _generateSyncInitFile(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final boxName = 'sync_metadata_$entitySnake';
    final fileName = '${entitySnake}_sync.dart';

    final syncPath = path.join(outputDir, 'sync', fileName);

    final directives = [Directive.import('package:zuraffa/zuraffa.dart')];

    final method = Method(
      (m) => m
        ..name = 'init${entityName}Sync'
        ..returns = _futureVoidType()
        ..modifier = MethodModifier.async
        ..docs.add('/// Auto-generated sync box init for $entityName')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('Hive')
                  .property('openBox')
                  .call(
                    [literalString(boxName)],
                    const {},
                    [refer('SyncMetadata')],
                  )
                  .awaited
                  .statement,
            ),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      syncPath,
      content,
      'sync_init',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  /// Generates `data/datasources/{entity_snake}/{entity_snake}_sync_metadata_store.dart`.
  ///
  /// Creates a SyncMetadataStore wrapper from the Hive box:
  /// ```dart
  /// SyncMetadataStore create{Entity}SyncMetadataStore() {
  ///   final box = Hive.box<SyncMetadata>('sync_metadata_{entity_snake}');
  ///   return SyncMetadataStore(box);
  /// }
  /// ```
  Future<GeneratedFile> _generateSyncMetadataStoreFile(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final boxName = 'sync_metadata_$entitySnake';
    final fileName = '${entitySnake}_sync_metadata_store.dart';

    final storePath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
      fileName,
    );

    final directives = [Directive.import('package:zuraffa/zuraffa.dart')];

    final boxDecl = declareFinal('box').assign(
      refer('Hive')
          .property('box')
          .call([literalString(boxName)], const {}, [refer('SyncMetadata')]),
    );

    final storeCall = refer('SyncMetadataStore').call([refer('box')]);

    final method = Method(
      (m) => m
        ..name = 'create${entityName}SyncMetadataStore'
        ..returns = refer('SyncMetadataStore')
        ..docs.add(
          '/// Auto-generated SyncMetadataStore factory for $entityName',
        )
        ..body = Block(
          (b) => b
            ..statements.add(boxDecl.statement)
            ..statements.add(storeCall.returned.statement),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      storePath,
      content,
      'sync_metadata_store',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  /// Generates `data/datasources/{entity_snake}/{entity_snake}_sync_strategy.dart`.
  ///
  /// Creates a PushOnlySyncStrategy or BidirectionalSyncStrategy wired to
  /// the entity's local/remote datasources:
  /// ```dart
  /// SyncStrategy<{Entity}> create{Entity}SyncStrategy({
  ///   required {EntityCamel}LocalDataSource localDataSource,
  ///   required {EntityCamel}RemoteDataSource remoteDataSource,
  ///   required SyncMetadataStore metadataStore,
  /// }) {
  ///   return PushOnlySyncStrategy<{Entity}>(
  ///     fetchLocal: (keys) => localDataSource.getByIds(keys),
  ///     createRemote: (entity) => remoteDataSource.create(entity),
  ///     updateRemote: (entity) => remoteDataSource.update(entity),
  ///     deleteRemote: (id) => remoteDataSource.delete(id),
  ///     keyResolver: (entity) => entity.id,
  ///     metadataStore: metadataStore,
  ///   );
  /// }
  /// ```
  Future<GeneratedFile> _generateSyncStrategyFile(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final fileName = '${entitySnake}_sync_strategy.dart';

    final strategyPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
      fileName,
    );

    final isBidirectional = config.syncDirection == 'bidirectional';

    final directives = [
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('${entitySnake}_local_data_source.dart'),
      Directive.import('${entitySnake}_remote_data_source.dart'),
      Directive.import('${entitySnake}_sync_metadata_store.dart'),
    ];

    // Build the localDataSource parameter
    final localDsParam = Parameter(
      (p) => p
        ..name = 'localDataSource'
        ..type = refer('${entityName}LocalDataSource'),
    );

    // Build the remoteDataSource parameter
    final remoteDsParam = Parameter(
      (p) => p
        ..name = 'remoteDataSource'
        ..type = refer('${entityName}RemoteDataSource'),
    );

    // Build the metadataStore parameter
    final metadataStoreParam = Parameter(
      (p) => p
        ..name = 'metadataStore'
        ..type = refer('SyncMetadataStore'),
    );

    // Build the SyncConfig
    final syncConfig = refer('SyncConfig').call([], {
      'batchSize': literalNum(config.syncBatchSize),
      'maxRetries': literalNum(config.syncMaxRetries),
      'backoffBaseMs': literalNum(config.syncBackoffBaseMs),
      'backoffMaxMs': literalNum(config.syncBackoffMaxMs),
      'direction': refer(
        isBidirectional ? 'SyncDirection.bidirectional' : 'SyncDirection.push',
      ),
    });

    // Build callback lambdas
    final fetchLocalLambda = _asyncLambda(
      [Parameter((p) => p..name = 'keys')],
      refer(
        'localDataSource',
      ).property('getByIds').call([refer('keys')]).awaited,
    );

    final createRemoteLambda = _asyncLambda(
      [Parameter((p) => p..name = entityCamel)],
      refer(
        'remoteDataSource',
      ).property('create').call([refer(entityCamel)]).awaited,
    );

    final updateRemoteLambda = _asyncLambda(
      [Parameter((p) => p..name = entityCamel)],
      refer(
        'remoteDataSource',
      ).property('update').call([refer(entityCamel)]).awaited,
    );

    final deleteRemoteLambda = _asyncLambda(
      [Parameter((p) => p..name = 'id')],
      refer('remoteDataSource').property('delete').call([refer('id')]).awaited,
    );

    final keyResolverLambda = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = entityCamel))
        ..lambda = true
        ..body = refer(entityCamel).property('id').code,
    ).closure;

    // Build the strategy constructor call
    final strategyArgs = <String, Expression>{
      'fetchLocal': fetchLocalLambda,
      'createRemote': createRemoteLambda,
      'updateRemote': updateRemoteLambda,
      'deleteRemote': deleteRemoteLambda,
      'keyResolver': keyResolverLambda,
      'metadataStore': refer('metadataStore'),
      'config': syncConfig,
    };

    if (isBidirectional) {
      strategyArgs['fetchRemoteList'] = _asyncLambda(
        [],
        refer('remoteDataSource').property('getAll').call([]).awaited,
      );
      strategyArgs['saveLocal'] = _asyncLambda(
        [Parameter((p) => p..name = entityCamel)],
        refer(
          'localDataSource',
        ).property('put').call([refer(entityCamel)]).awaited,
      );
    }

    final strategyClass = isBidirectional
        ? 'BidirectionalSyncStrategy'
        : 'PushOnlySyncStrategy';

    final strategyCall = refer(
      strategyClass,
    ).call([], strategyArgs, [refer(entityName)]);

    final method = Method(
      (m) => m
        ..name = 'create${entityName}SyncStrategy'
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'SyncStrategy'
            ..types.add(refer(entityName)),
        )
        ..requiredParameters.addAll([
          localDsParam,
          remoteDsParam,
          metadataStoreParam,
        ])
        ..docs.add(
          '/// Auto-generated sync strategy factory for $entityName '
          '(${config.syncDirection})',
        )
        ..body = Block(
          (b) => b..statements.add(strategyCall.returned.statement),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      strategyPath,
      content,
      'sync_strategy',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  /// Regenerates `sync/index.dart` that calls all sync init functions.
  ///
  /// Scans the sync directory for `*_sync.dart` files and builds an
  /// `initAllSyncs()` function that calls each entity's init function.
  Future<void> _regenerateSyncIndex(GeneratorConfig config) async {
    final dirPath = path.join(outputDir, 'sync');
    final indexPath = path.join(dirPath, 'index.dart');

    if (!await fileSystem.exists(dirPath)) {
      return;
    }

    final items = await fileSystem.list(dirPath);
    final files = <String>[];
    for (final item in items) {
      if (!await fileSystem.isDirectory(item)) {
        if (item.endsWith('_sync.dart') && !item.endsWith('index.dart')) {
          files.add(item);
        }
      }
    }

    if (files.isEmpty) {
      if (await fileSystem.exists(indexPath)) {
        if (options.dryRun) {
          if (options.verbose) print('  Dry run: Deleting $indexPath');
        } else {
          await fileSystem.delete(indexPath);
        }
      }
      return;
    }

    final exports = <String>[];
    final imports = <String>[];
    final statements = <Code>[];

    for (final filePath in files) {
      final fileName = path.basename(filePath);
      final entitySnake = fileName.replaceAll('_sync.dart', '');
      final entityName = StringUtils.convertToPascalCase(entitySnake);
      exports.add(fileName);
      imports.add(fileName);
      statements.add(refer('init${entityName}Sync').call([]).awaited.statement);
    }

    final directives = [
      ...exports.map(Directive.export),
      ...imports.map(Directive.import),
    ];

    final initAllSyncs = Method(
      (m) => m
        ..name = 'initAllSyncs'
        ..returns = _futureVoidType()
        ..modifier = MethodModifier.async
        ..docs.add('/// Auto-generated - DO NOT EDIT')
        ..body = Block((b) => b..statements.addAll(statements)),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [initAllSyncs], directives: directives),
    );

    await FileUtils.writeFile(
      indexPath,
      content,
      'sync_index',
      force: true,
      dryRun: config.dryRun,
      verbose: config.verbose,
      fileSystem: fileSystem,
    );
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Builds an async lambda: `(params) async => body`
  Expression _asyncLambda(List<Parameter> params, Expression body) {
    final method = Method(
      (m) => m
        ..requiredParameters.addAll(params)
        ..modifier = MethodModifier.async
        ..lambda = true
        ..body = body.code,
    );
    return method.closure;
  }

  /// Returns `Future<void>` type reference.
  TypeReference _futureVoidType() {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(refer('void')),
    );
  }
}
