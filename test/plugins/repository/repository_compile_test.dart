import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

import '../../helpers/project_root.dart';

/// Spec 1003 (T003) — compile gate for the `repository` trust-tier
/// generator, covering the simple / synced / cached / append variants.
///
/// All four variants generate into dedicated sub-roots of ONE self-contained
/// pure-Dart temp project (pubspec with a path dependency on this repo).
/// Imports the generator delegates to the datasource/cache layer are backed
/// by hand-written stubs mirroring the generated shapes; the variants'
/// datasource interfaces for the simple root are produced by the plugin
/// itself (`generateDataSource: true`). `dart pub get` once, then
/// `dart analyze` over the whole project must exit 0.
void main() {
  late Directory projectRoot;
  late String repoRoot;

  setUpAll(() async {
    repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp(
      'zuraffa_repo_compile_',
    );
    await File('${projectRoot.path}/pubspec.yaml').create(recursive: true);
    await File('${projectRoot.path}/pubspec.yaml').writeAsString('''
name: repository_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');

    // simple — fully self-generated (interface + impl + datasource).
    final simpleRoot = Directory(p.join(projectRoot.path, 'simple'));
    await _writeEntityStub(simpleRoot);
    await RepositoryPlugin(
      outputDir: simpleRoot.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList'],
        generateRepository: true,
        generateData: true,
        generateDataSource: true,
        outputDir: simpleRoot.path,
      ),
    );

    // synced — plugin output + datasource stubs it delegates to.
    final syncedRoot = Directory(p.join(projectRoot.path, 'synced'));
    await _writeEntityStub(syncedRoot);
    await _writeDatasourceStubs(syncedRoot);
    await RepositoryPlugin(
      outputDir: syncedRoot.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList'],
        generateRepository: true,
        enableSync: true,
        outputDir: syncedRoot.path,
      ),
    );

    // cached — plugin output + cache plugin + datasource stubs.
    final cachedRoot = Directory(p.join(projectRoot.path, 'cached'));
    await _writeEntityStub(cachedRoot);
    await _writeDatasourceStubs(cachedRoot);
    await CachePlugin(
      outputDir: cachedRoot.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: cachedRoot.path,
      ),
    );
    await RepositoryPlugin(
      outputDir: cachedRoot.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generateRepository: true,
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: cachedRoot.path,
      ),
    );

    // append — baseline generation, then append watch.
    final appendRoot = Directory(p.join(projectRoot.path, 'append'));
    await _writeEntityStub(appendRoot);
    await _writeDatasourceStubs(appendRoot, withWatch: true);
    await RepositoryPlugin(
      outputDir: appendRoot.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList'],
        generateRepository: true,
        generateData: true,
        outputDir: appendRoot.path,
      ),
    );
    await RepositoryPlugin(
      outputDir: appendRoot.path,
      options: const GeneratorOptions(dryRun: false, force: false),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['watch'],
        generateRepository: true,
        appendToExisting: true,
        outputDir: appendRoot.path,
      ),
    );

    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: projectRoot.path);
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get must succeed in the compile fixture.\n'
          '${pub.stdout}\n${pub.stderr}',
    );

    // The cache plugin side-writes cache/hive_registrar.dart whose
    // `part 'hive_registrar.g.dart'` adapter file is produced by the
    // documented `build_runner build` step (zfa entity create --build).
    // Emit the post-build adapter for the cached root so the variant can
    // be gated without spinning up build_runner.
    final registrarPart = File(
      p.join(cachedRoot.path, 'cache', 'hive_registrar.g.dart'),
    );
    await registrarPart.create(recursive: true);
    await registrarPart.writeAsString('''
// GENERATED - DO NOT EDIT
// Simulates the hive_ce generator output for @GenerateAdapters.
part of 'hive_registrar.dart';

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 1;

  @override
  Product read(BinaryReader reader) => Product();

  @override
  void write(BinaryWriter writer, Product obj) {}
}
''');
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) {
      await projectRoot.delete(recursive: true);
    }
  });

  test('all repository variants pass dart analyze (exit 0)', () async {
    for (final variant in ['simple', 'synced', 'cached', 'append']) {
      expect(
        File(
          p.join(
            projectRoot.path,
            variant,
            'data',
            'repositories',
            'data_product_repository.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: '$variant variant must write the data repository',
      );
    }

    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      projectRoot.path,
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason:
          'simple/synced/cached/append repository variants must analyze '
          'clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in repository variant output:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _writeEntityStub(Directory root) async {
  await File(
    p.join(root.path, 'domain', 'entities', 'product', 'product.dart'),
  ).create(recursive: true);
  await File(
    p.join(root.path, 'domain', 'entities', 'product', 'product.dart'),
  ).writeAsString('''
class Product {
  Product({this.id});

  final String? id;
}
''');
}

/// Writes the data-layer files the synced/cached/append variants delegate
/// to but do not generate themselves (the sync pipeline owns the
/// local/remote/metadata files; the append baseline owns watch).
Future<void> _writeDatasourceStubs(
  Directory root, {
  bool withWatch = false,
}) async {
  final dir = p.join(root.path, 'data', 'datasources', 'product');
  await Directory(dir).create(recursive: true);
  await File(p.join(dir, 'product_datasource.dart')).create(recursive: true);
  await File(p.join(dir, 'product_datasource.dart')).writeAsString('''
import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

abstract class ProductDataSource with Loggable, FailureHandler {
  Future<Product> get(QueryParams<Product> params);

  Future<List<Product>> getList(ListQueryParams<Product> params);
${withWatch ? '''
  Stream<Product> watch(QueryParams<Product> params);
''' : ''}}
''');
  await File(
    p.join(dir, 'product_local_datasource.dart'),
  ).create(recursive: true);
  await File(p.join(dir, 'product_local_datasource.dart')).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

class ProductLocalDataSource {
  Future<Product> get(QueryParams<Product> params) async {
    throw UnimplementedError();
  }

  Future<List<Product>> getList(ListQueryParams<Product> params) async {
    throw UnimplementedError();
  }

  Future<void> save(Product entity) async {}

  Future<void> saveAll(List<Product> entities) async {}
}
''');
  await File(
    p.join(dir, 'product_remote_datasource.dart'),
  ).create(recursive: true);
  await File(p.join(dir, 'product_remote_datasource.dart')).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

class ProductRemoteDataSource {
  Future<Product> get(QueryParams<Product> params) async {
    throw UnimplementedError();
  }
}
''');
  // zuraffa core already exports `SyncMetadataStore`; the sync pipeline's
  // metadata file resolves against that export, so this stub stays empty.
  await File(
    p.join(dir, 'product_sync_metadata_store.dart'),
  ).create(recursive: true);
  await File(
    p.join(dir, 'product_sync_metadata_store.dart'),
  ).writeAsString('// Backing file for the sync metadata store import.\n');
}
