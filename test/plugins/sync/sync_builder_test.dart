import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/sync/builders/sync_builder.dart';

/// Tests for [SyncBuilder] file generation (T048, FR-014).
///
/// Verifies that enabling sync generates the box-init file, metadata store
/// factory, strategy factory, and the `Sync<Entity>UseCase` (FR-007, T030).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_sync_builder_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<GeneratorConfig> config0({
    String direction = 'push',
    List<String> methods = const [
      'get',
      'getList',
      'create',
      'update',
      'delete',
    ],
  }) async {
    return GeneratorConfig(
      name: 'Product',
      methods: methods,
      enableSync: true,
      syncDirection: direction,
      syncBatchSize: 50,
      syncMaxRetries: 5,
      outputDir: outputDir,
      force: true,
    );
  }

  test('generates sync box init file', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generate(await config0());

    final initFile = File('$outputDir/sync/product_sync.dart');
    expect(
      initFile.existsSync(),
      isTrue,
      reason: 'sync init file should be generated',
    );
    final content = initFile.readAsStringSync();
    expect(content, contains('initProductSync'));
    expect(
      content,
      contains("Hive.openBox<SyncMetadata>('sync_metadata_product')"),
    );
  });

  test('generates sync metadata store factory', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generate(await config0());

    final storeFile = File(
      '$outputDir/data/datasources/product/product_sync_metadata_store.dart',
    );
    expect(
      storeFile.existsSync(),
      isTrue,
      reason: 'sync metadata store file should be generated',
    );
    final content = storeFile.readAsStringSync();
    expect(content, contains('createProductSyncMetadataStore'));
    expect(content, contains('SyncMetadataStore'));
    expect(
      content,
      contains("Hive.box<SyncMetadata>('sync_metadata_product')"),
    );
  });

  test('generates push-only sync strategy factory', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generate(await config0(direction: 'push'));

    final strategyFile = File(
      '$outputDir/data/datasources/product/product_sync_strategy.dart',
    );
    expect(
      strategyFile.existsSync(),
      isTrue,
      reason: 'sync strategy file should be generated',
    );
    final content = strategyFile.readAsStringSync();
    expect(content, contains('createProductSyncStrategy'));
    expect(content, contains('PushOnlySyncStrategy<Product>'));
    expect(content, contains('SyncDirection.push'));
  });

  test('generates bidirectional sync strategy factory', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generate(await config0(direction: 'bidirectional'));

    final strategyFile = File(
      '$outputDir/data/datasources/product/product_sync_strategy.dart',
    );
    final content = strategyFile.readAsStringSync();
    expect(content, contains('BidirectionalSyncStrategy<Product>'));
    expect(content, contains('SyncDirection.bidirectional'));
    expect(content, contains('fetchRemoteList'));
    expect(content, contains('saveLocal'));
  });

  test('generates SyncEntityUseCase (FR-007, T030)', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generate(await config0());

    final useCaseFile = File(
      '$outputDir/domain/usecases/product/product_sync_usecase.dart',
    );
    expect(
      useCaseFile.existsSync(),
      isTrue,
      reason: 'SyncProductUseCase should be generated',
    );
    final content = useCaseFile.readAsStringSync();
    expect(
      content,
      contains('class SyncProductUseCase extends UseCase<void, NoParams>'),
    );
    expect(content, contains('final ProductRepository _repository;'));
    expect(content, contains('SyncProductUseCase(this._repository);'));
    expect(
      content,
      contains(
        'Future<void> execute(NoParams params, CancelToken? cancelToken) async',
      ),
    );
    expect(content, contains('cancelToken?.throwIfCancelled();'));
    expect(
      content,
      contains('await _repository.syncPending(cancelToken: cancelToken);'),
    );
  });

  test('revert removes generated sync usecase file', () async {
    final builder = SyncBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final config = await config0();
    await builder.generate(config);

    final useCaseFile = File(
      '$outputDir/domain/usecases/product/product_sync_usecase.dart',
    );
    expect(useCaseFile.existsSync(), isTrue);

    // Sync revert is driven with sync enabled + revert flag set, mirroring how
    // `zfa make <Entity> --sync --revert` tears the generated stack down.
    final revertConfig = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      enableSync: true,
      revert: true,
      outputDir: outputDir,
      force: true,
    );
    await builder.generate(revertConfig);

    expect(
      useCaseFile.existsSync(),
      isFalse,
      reason: 'sync usecase should be removed on revert',
    );
  });
}
