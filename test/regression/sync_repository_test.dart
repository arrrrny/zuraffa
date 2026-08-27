@Tags(['regression', 'slow'])
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

/// Regression tests for the sync-enabled repository generation (T054, FR-014).
///
/// Verifies the generated `Data<Product>Repository` has local-first write
/// methods, local-only read methods, tombstone deletes, a `syncPending()`
/// method that delegates to the strategy, and a 4-dependency constructor.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_sync_repo_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> _generateRepo({List<String> methods = const ['get', 'getList', 'create', 'update', 'delete']}) async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: methods,
        generateData: true,
        generateDataSource: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      ),
    );
    return File('$outputDir/data/repositories/data_product_repository.dart')
        .readAsStringSync();
  }

  test('repository constructor has 4 sync dependencies', () async {
    final content = await _generateRepo();

    expect(content, contains('_localDataSource'));
    expect(content, contains('_remoteDataSource'));
    expect(content, contains('_syncMetadataStore'));
    expect(content, contains('_syncStrategy'));
    // The injected strategy type is SyncStrategy<Product>.
    expect(content, contains('SyncStrategy<Product>'));
  });

  test('create() writes to local and marks pending', () async {
    final content = await _generateRepo();

    expect(content, contains('_localDataSource.create'));
    expect(content, contains('_syncStrategy.markPending'));
    expect(content, contains('SyncOperation.create'));
  });

  test('update() writes to local and marks pending', () async {
    final content = await _generateRepo();

    expect(content, contains('_localDataSource.update'));
    expect(content, contains('SyncOperation.update'));
  });

  test('get() reads from local only (no remote call)', () async {
    final content = await _generateRepo();

    expect(content, contains('_localDataSource.get'));
    expect(content, isNot(contains('_remoteDataSource.get')));
  });

  test('getList() reads from local only (no remote call)', () async {
    final content = await _generateRepo(methods: const ['getList']);

    expect(content, contains('_localDataSource.getList'));
    expect(content, isNot(contains('_remoteDataSource.getList')));
  });

  test('delete() hard-deletes locally and tombstones for remote', () async {
    final content = await _generateRepo();

    expect(content, contains('_localDataSource.delete'));
    expect(content, contains('_syncStrategy.markDeleted'));
  });

  test('syncPending() delegates to the sync strategy', () async {
    final content = await _generateRepo();

    expect(content, contains('Future<void> syncPending('));
    expect(content, contains('_syncStrategy.syncPending'));
  });

  test('pullRemote() delegates to the sync strategy', () async {
    final content = await _generateRepo();

    expect(content, contains('Future<void> pullRemote('));
    expect(content, contains('_syncStrategy.pullRemote'));
  });

  test('abstract repository interface exposes sync operations', () async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList', 'create', 'update', 'delete'],
        generateData: true,
        generateDataSource: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      ),
    );

    final interface = File(
      '$outputDir/domain/repositories/product_repository.dart',
    ).readAsStringSync();

    expect(interface, contains('Future<void> syncPending('));
    expect(interface, contains('Future<void> pullRemote('));
  });
}
