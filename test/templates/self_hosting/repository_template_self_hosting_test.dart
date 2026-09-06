// Bug 1198 (part of #908 P0) — template self-hosting: `repository` template.
//
// Full trust-tier loop against the fixture entity: structural + compile +
// behavioral (generated repository EXECUTES over a stub datasource) +
// byte-stability diff guard (#1198 harness).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('repository', repoRoot);
    bare = await createTempFixture('repository_bare');
    await writeFixtureEntity(bare);
  });

  tearDownAll(() async {
    if (fixture.existsSync()) fixture.delete(recursive: true);
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final files =
        await RepositoryPlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateRepository: true,
            generateData: true,
            generateDataSource: true,
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits interface + data impl + datasource interface', () async {
      final files = await generateInto(bare);
      final paths = files.map((f) => f.path).toSet();
      expect(
        paths,
        containsAll(<Matcher>[
          contains('domain/repositories/product_repository.dart'),
          contains('data/repositories/data_product_repository.dart'),
          contains('data/datasources/product/product_datasource.dart'),
        ]),
      );
    });

    test('declares the fixture-entity contract on every layer', () async {
      final files = await generateInto(bare);
      String contentOf(String suffix) => generatedContent(files, bare, suffix);

      final interface = contentOf(
        'domain/repositories/product_repository.dart',
      );
      expect(interface, contains('abstract class ProductRepository {'));
      expect(
        interface,
        contains('Future<Product> get(QueryParams<Product> params);'),
      );

      final impl = contentOf('data/repositories/data_product_repository.dart');
      expect(
        impl,
        contains(
          'class DataProductRepository\n'
          '    with Loggable, FailureHandler\n'
          '    implements ProductRepository {',
        ),
      );
      expect(impl, contains('DataProductRepository(this._dataSource);'));

      final ds = contentOf('product_datasource.dart');
      expect(ds, contains('abstract class ProductDataSource'));
    });
  });

  group('compile', () {
    test('generated repository layers analyze clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'repository');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test('generated repository executes over a stub datasource', () async {
      await generateInto(fixture);

      final script = File(p.join(fixture.path, 'tool', 'behavior_check.dart'));
      await script.parent.create(recursive: true);
      await script.writeAsString('''
// Bug 1198 behavioral tier — executes the GENERATED repository over a
// stub datasource. Fails the loop when the generated wiring cannot run.
import 'package:zuraffa/zuraffa.dart';

import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/data/datasources/product/product_datasource.dart';
import '../lib/src/data/repositories/data_product_repository.dart';

class StubProductDataSource with Loggable, FailureHandler
    implements ProductDataSource {
  @override
  Future<Product> get(QueryParams<Product> params) async {
    return Product(
      id: 'p1',
      name: 'Desk',
      price: 42.0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async =>
      <Product>[];
}

Future<void> main() async {
  final repository = DataProductRepository(StubProductDataSource());
  final product = await repository.get(const QueryParams<Product>());
  if (product.id != 'p1') {
    throw StateError('behavior check failed: repository did not emit the '
        'fixture entity');
  }
  final list = await repository.getList(const ListQueryParams<Product>());
  if (list.isNotEmpty) {
    throw StateError('behavior check failed: expected the stub empty list');
  }
}
''');
      final run = await runBehaviorScript(fixture, script.path);
      expect(
        run.exitCode,
        0,
        reason:
            'generated repository must EXECUTE (behavioral tier):\n'
            '${run.stdout}\n${run.stderr}',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'repository',
          generate: (root) async {
            final files =
                await RepositoryPlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateRepository: true,
                    generateData: true,
                    generateDataSource: true,
                    outputDir: p.join(root.path, 'lib', 'src'),
                  ),
                );
            return files
                .map((f) => (path: f.path, content: f.content))
                .toList();
          },
        );
      },
    );
  });
}
