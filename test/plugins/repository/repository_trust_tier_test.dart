import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

/// Spec 1003 (T003) — dedicated structural tests for the `repository`
/// trust-tier generator, one per variant: simple, synced, append
/// (`test/plugins/repository/`).
///
/// Each variant generates into a throwaway temp dir; assertions cover file
/// count + key content (class name, imports, method signatures, expected
/// stub bodies).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_repo_tier_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RepositoryPlugin buildPlugin({bool force = true}) => RepositoryPlugin(
    outputDir: outputDir,
    options: GeneratorOptions(dryRun: false, force: force),
  );

  group('simple variant', () {
    test(
      'emits interface + data implementation + datasource interface',
      () async {
        final files = await buildPlugin().generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get', 'getList'],
            generateRepository: true,
            generateData: true,
            generateDataSource: true,
            outputDir: outputDir,
          ),
        );

        expect(files, hasLength(3));
        final paths = files.map((f) => f.path).toSet();
        expect(
          paths,
          containsAll(<Matcher>[
            contains('domain/repositories/product_repository.dart'),
            contains('data/repositories/data_product_repository.dart'),
            contains('data/datasources/product/product_datasource.dart'),
          ]),
        );

        final interface = File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).readAsStringSync();
        expect(interface, contains('abstract class ProductRepository {'));
        expect(
          interface,
          contains('Future<Product> get(QueryParams<Product> params);'),
        );
        expect(
          interface,
          contains(
            'Future<List<Product>> getList(ListQueryParams<Product> params);',
          ),
        );

        final impl = File(
          '$outputDir/data/repositories/data_product_repository.dart',
        ).readAsStringSync();
        expect(
          impl,
          contains(
            'class DataProductRepository\n'
            '    with Loggable, FailureHandler\n'
            '    implements ProductRepository {',
          ),
        );
        expect(impl, contains('DataProductRepository(this._dataSource);'));
        expect(impl, contains('final ProductDataSource _dataSource;'));
        expect(
          impl,
          contains("import '../datasources/product/product_datasource.dart';"),
        );

        final datasource = File(
          '$outputDir/data/datasources/product/product_datasource.dart',
        ).readAsStringSync();
        expect(datasource, contains('abstract class ProductDataSource'));
      },
    );
  });

  group('synced variant', () {
    test(
      'adds sync methods to interface and sync strategy wiring to impl',
      () async {
        final files = await buildPlugin().generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get', 'getList'],
            generateRepository: true,
            enableSync: true,
            outputDir: outputDir,
          ),
        );

        expect(files, hasLength(2));

        final interface = File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).readAsStringSync();
        expect(
          interface,
          contains('Future<void> syncPending({CancelToken? cancelToken});'),
        );
        expect(
          interface,
          contains('Future<void> pullRemote({CancelToken? cancelToken});'),
        );

        final impl = File(
          '$outputDir/data/repositories/data_product_repository.dart',
        ).readAsStringSync();
        expect(
          impl,
          contains(
            "import '../datasources/product/product_local_datasource.dart';",
          ),
        );
        expect(
          impl,
          contains(
            "import '../datasources/product/product_remote_datasource.dart';",
          ),
        );
        expect(
          impl,
          contains(
            "import '../datasources/product/product_sync_metadata_store.dart';",
          ),
        );
        expect(impl, contains('final SyncStrategy<Product> _syncStrategy;'));
        expect(impl, contains('final SyncMetadataStore _syncMetadataStore;'));
        expect(
          impl,
          contains('Future<void> syncPending({CancelToken? cancelToken})'),
        );
        expect(
          impl,
          contains('await _syncStrategy.syncPending(cancelToken: cancelToken)'),
        );
        expect(
          impl,
          contains('Future<void> pullRemote({CancelToken? cancelToken})'),
        );
        expect(
          impl,
          contains('await _syncStrategy.pullRemote(cancelToken: cancelToken)'),
        );
      },
    );
  });

  group('append variant', () {
    test(
      'appends new methods while preserving existing repository methods',
      () async {
        // Pass 1 — baseline repository (get + getList).
        await buildPlugin().generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get', 'getList'],
            generateRepository: true,
            outputDir: outputDir,
          ),
        );

        // Pass 2 — append watch to the existing repository.
        final files = await buildPlugin(force: false).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['watch'],
            generateRepository: true,
            appendToExisting: true,
            outputDir: outputDir,
          ),
        );
        expect(files, isNotEmpty);

        final interface = File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).readAsStringSync();
        expect(interface, contains('Future<Product> get('));
        expect(interface, contains('Future<List<Product>> getList('));
        expect(interface, contains('Stream<Product> watch('));

        final impl = File(
          '$outputDir/data/repositories/data_product_repository.dart',
        ).readAsStringSync();
        expect(impl, contains('Stream<Product> watch('));
        expect(impl, contains('_dataSource.watch(params)'));
      },
    );

    test('append never emits augment files', () async {
      await buildPlugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['get'],
          generateRepository: true,
          outputDir: outputDir,
        ),
      );
      await buildPlugin(force: false).generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['watch'],
          generateRepository: true,
          appendToExisting: true,
          outputDir: outputDir,
        ),
      );

      expect(
        File(
          '$outputDir/domain/repositories/product_repository.augment.dart',
        ).existsSync(),
        isFalse,
      );
    });
  });
}
