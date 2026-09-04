import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

/// Spec 0973 (issue #973) — variant content tests.
///
/// The repository plugin emits three impl variants (simple, cached,
/// synced) plus an append flow. Only cached-stream had coverage; these
/// tests assert the actual emitted CONTENT of the remaining variants so
/// template regressions fail here, not downstream at `zfa build`.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_variants_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RepositoryPlugin plugin({bool force = true}) => RepositoryPlugin(
    outputDir: outputDir,
    options: GeneratorOptions(dryRun: false, force: force, verbose: false),
  );

  group('simple variant (no cache, no sync)', () {
    test('delegates directly to the data source with no cache machinery',
        () async {
      final config = GeneratorConfig(
        name: 'Order',
        methods: ['get', 'getList', 'create', 'update', 'delete'],
        generateData: true,
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin().generate(config);
      final impl = files.firstWhere(
        (f) => f.path.contains('data_order_repository.dart'),
      );
      final content = impl.content ?? '';

      // Direct delegation to the single data source.
      final normalized = content.replaceAll(RegExp(r'\s+'), '');
      expect(normalized, contains('_dataSource.get'));
      expect(normalized, contains('_dataSource.getList'));
      expect(normalized, contains('_dataSource.create'));
      expect(normalized, contains('_dataSource.update'));
      expect(normalized, contains('_dataSource.delete'));

      // Every CRUD method claims the interface.
      expect('override'.allMatches(content).length, greaterThanOrEqualTo(5));

      // No cache/sync machinery leaks into the simple variant.
      expect(content, isNot(contains('_localDataSource')));
      expect(content, isNot(contains('_remoteDataSource')));
      expect(content, isNot(contains('_cachePolicy')));
      expect(content, isNot(contains('_syncStrategy')));
      expect(content, isNot(contains('syncPending')));
      expect(content, isNot(contains('markPending')));

      // Constructor takes exactly one data source.
      expect(
        RegExp(r'DataOrderRepository\(this\._dataSource\)').hasMatch(content),
        isTrue,
        reason: 'constructor wires exactly one data source',
      );

      // Interface side: declares the same CRUD surface, no sync ops.
      final interface = files.firstWhere(
        (f) => f.path.contains('order_repository.dart'),
      );
      final interfaceContent = interface.content ?? '';
      expect(interfaceContent, contains('Future<Order> get('));
      expect(interfaceContent, contains('Future<List<Order>> getList('));
      expect(interfaceContent, isNot(contains('syncPending')));
      expect(interfaceContent, isNot(contains('pullRemote')));
    });
  });

  group('synced variant (--sync)', () {
    test('reads local-first, marks pending writes, exposes sync ops',
        () async {
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'getList', 'create', 'update', 'delete', 'watch'],
        generateData: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin().generate(config);
      final impl = files.firstWhere(
        (f) => f.path.contains('data_task_repository.dart'),
      );
      final content = impl.content ?? '';
      final normalized = content.replaceAll(RegExp(r'\s+'), '');

      // Reads delegate to local ONLY — no network on the read path.
      expect(normalized, contains('_localDataSource.get'));
      expect(normalized, contains('_localDataSource.getList'));
      expect(normalized, contains('_localDataSource.watch'));

      // Writes go local first, then mark pending via the sync strategy.
      expect(normalized, contains('_localDataSource.create'));
      expect(normalized, contains('_localDataSource.update'));
      expect(normalized, contains('_localDataSource.delete'));
      expect(normalized, contains('_syncStrategy.markPending'));
      expect(normalized, contains('SyncOperation.create'));
      expect(normalized, contains('SyncOperation.update'));
      expect(normalized, contains('_syncStrategy.markDeleted'));

      // Sync operations delegate to the strategy and carry @override.
      expect(content, contains('Future<void> syncPending('));
      expect(content, contains('Future<void> pullRemote('));
      expect(normalized, contains('_syncStrategy.syncPending'));
      expect(normalized, contains('_syncStrategy.pullRemote'));

      // Constructor wires local, remote, metadata store and strategy.
      expect(content, contains('this._localDataSource'));
      expect(content, contains('this._remoteDataSource'));
      expect(content, contains('this._syncMetadataStore'));
      expect(content, contains('this._syncStrategy'));

      // Interface declares the sync operations the impl overrides.
      final interface = files.firstWhere(
        (f) => f.path.contains('task_repository.dart'),
      );
      final interfaceContent = interface.content ?? '';
      expect(interfaceContent, contains('Future<void> syncPending('));
      expect(interfaceContent, contains('Future<void> pullRemote('));
    });
  });

  group('append variant (--append onto an existing pair)', () {
    test('preserves existing members and appends the new method set',
        () async {
      final interfacePath =
          '$outputDir/domain/repositories/product_repository.dart';
      final implPath =
          '$outputDir/data/repositories/data_product_repository.dart';
      await File(interfacePath).create(recursive: true);
      await File(implPath).create(recursive: true);
      await File(interfacePath).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

abstract class ProductRepository {
  Future<void> customReport();
}
''');
      await File(implPath).writeAsString('''
import '../../domain/repositories/product_repository.dart';

class DataProductRepository implements ProductRepository {
  Future<void> customReport() async {}
}
''');

      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        appendToExisting: true,
        generateData: true,
        outputDir: outputDir,
        force: false,
      );

      // The generation-time conformance gate (spec 0973) runs in delta
      // scope here: the run asserts ITS OWN additions, so pre-existing
      // members cannot fail it — but the appended pair must still conform.
      final files = await plugin(force: false).generate(config);
      expect(files, isNotEmpty);

      final interfaceContent = File(interfacePath).readAsStringSync();
      final implContent = File(implPath).readAsStringSync();

      // Pre-existing members survive.
      expect(interfaceContent, contains('customReport'));
      expect(implContent, contains('customReport'));

      // The new method set is appended to BOTH sides.
      expect(interfaceContent, contains('Future<Product> get('));
      expect(interfaceContent, contains('Future<Product> update('));
      expect(implContent, contains('Future<Product> get('));
      expect(implContent, contains('Future<Product> update('));
      expect(implContent, contains('@override'));

      // No duplicate emission of the appended methods.
      expect(
        'Future<Product> get('.allMatches(interfaceContent).length,
        1,
        reason: 'append must not double-add the same method',
      );
      expect(
        'Future<Product> get('.allMatches(implContent).length,
        1,
      );

      // No augment files: append writes the host file directly.
      expect(
        File(
          '$outputDir/domain/repositories/product_repository.augment.dart',
        ).existsSync(),
        isFalse,
      );
    });
  });
}
