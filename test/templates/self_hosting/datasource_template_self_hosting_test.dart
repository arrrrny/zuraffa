// Bug 1198 (part of #908 P0) — template self-hosting: `datasource` template.
//
// Full trust-tier loop against the fixture entity: structural (interface +
// local + remote) + compile + behavioral (generated contract implementable
// and callable) + byte-stability diff guard (#1198 harness).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('datasource', repoRoot);
    bare = await createTempFixture('datasource_bare');
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
        await DataSourcePlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateData: true,
            enableCache: true,
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits interface + local + remote at the canonical paths', () async {
      final files = await generateInto(bare);
      final paths = files.map((f) => f.path).toSet();
      expect(
        paths,
        containsAll(<Matcher>[
          contains('data/datasources/product/product_datasource.dart'),
          contains('data/datasources/product/product_local_datasource.dart'),
          contains('data/datasources/product/product_remote_datasource.dart'),
        ]),
      );
    });

    test(
      'remote/local implementations implement the generated interface',
      () async {
        final files = await generateInto(bare);
        final interface = files
            .firstWhere((f) => f.path.endsWith('product_datasource.dart'))
            .content!;
        expect(interface, contains('abstract class ProductDataSource'));
        expect(
          interface,
          contains('Future<Product> get(QueryParams<Product> params);'),
        );

        final local = files
            .firstWhere((f) => f.path.endsWith('product_local_datasource.dart'))
            .content!;
        expect(local, contains('implements ProductDataSource'));
        expect(local, contains('Future<void> clear()'));
      },
    );
  });

  group('compile', () {
    test('generated datasources analyze clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(
        await analyzeFixture(fixture),
        context: 'datasources',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test(
      'generated datasource contract is implementable and callable',
      () async {
        await generateInto(fixture);

        final script = File(
          p.join(fixture.path, 'tool', 'behavior_check.dart'),
        );
        await script.parent.create(recursive: true);
        await script.writeAsString('''
// Bug 1198 behavioral tier — implements the GENERATED datasource interface
// (the in-memory contract the local/remote stubs are meant to be filled
// with) and executes it. Fails the loop when the emitted contract cannot
// be satisfied or called.
import 'package:zuraffa/zuraffa.dart';

import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/data/datasources/product/product_datasource.dart';

class InMemoryProductDataSource with Loggable, FailureHandler
    implements ProductDataSource {
  final items = <Product>[
    Product(
      id: 'p1',
      name: 'Desk',
      price: 7.25,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  @override
  Future<Product> get(QueryParams<Product> params) async => items.first;

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async =>
      items;
}

Future<void> main() async {
  final ProductDataSource dataSource = InMemoryProductDataSource();
  final product = await dataSource.get(const QueryParams<Product>());
  if (product.name != 'Desk') {
    throw StateError('behavior check failed: datasource contract broken');
  }
  final list = await dataSource.getList(const ListQueryParams<Product>());
  if (list.length != 1) {
    throw StateError('behavior check failed: list contract broken');
  }
}
''');
        final run = await runBehaviorScript(fixture, script.path);
        expect(
          run.exitCode,
          0,
          reason:
              'generated datasource contract must be implementable and '
              'callable (behavioral tier):\n${run.stdout}\n${run.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'datasource',
          generate: (root) async {
            final files =
                await DataSourcePlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateData: true,
                    enableCache: true,
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
