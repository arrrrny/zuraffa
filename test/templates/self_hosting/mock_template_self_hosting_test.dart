// Bug 1198 (part of #908 P0) — template self-hosting: `mock` template
// (the mock-first realization bar — #908 P0).
//
// Full trust-tier loop against the fixture entity: structural + compile +
// behavioral (the generated mock datasource EXECUTES and returns fixture
// data — the mock-first contract) + byte-stability diff guard.
//
// The fixture entity deliberately requires a `DateTime` field: that is the
// field class whose value used to be derived from the wall clock on the
// unseeded path — the byte-stability debt this loop exists to catch.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('mock', repoRoot);
    bare = await createTempFixture('mock_bare');
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
        await MockPlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateMock: true,
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits mock data + mock datasource (+ simulation binding)', () async {
      final files = await generateInto(bare);
      final paths = files.map((f) => f.path).toSet();
      expect(
        paths,
        containsAll(<Matcher>[
          contains('data/mock/product_mock_data.dart'),
          contains('data/datasources/product/product_mock_datasource.dart'),
          // spec 893 simulation binding surface.
          contains('di/simulation/product_simulation_datasource_di.dart'),
        ]),
      );
    });

    test('mock data covers every required fixture-entity field', () async {
      final files = await generateInto(bare);
      final mockData = files
          .firstWhere((f) => f.path.endsWith('product_mock_data.dart'))
          .content!;
      // The fixture entity's constructor requires all four fields — the
      // emitted mock instances must supply every one of them or the
      // compile tier below fails.
      expect(mockData, contains("id: 'id 1'"));
      expect(mockData, contains('name:'));
      expect(mockData, contains('price:'));
      expect(mockData, contains('createdAt:'));
    });
  });

  group('compile', () {
    test('generated mocks analyze clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'mocks');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test(
      'generated mock datasource executes and returns fixture data',
      () async {
        await generateInto(fixture);

        final script = File(
          p.join(fixture.path, 'tool', 'behavior_check.dart'),
        );
        await script.parent.create(recursive: true);
        await script.writeAsString('''
// Bug 1198 behavioral tier — executes the GENERATED mock datasource (the
// mock-first contract: consumers run against this before the real
// datasource exists).
import 'package:zuraffa/zuraffa.dart';

import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/data/datasources/product/product_mock_datasource.dart';

Future<void> main() async {
  final dataSource = ProductMockDataSource();
  final product = await dataSource.get(const QueryParams<Product>());
  if (product.id != 'id 1') {
    throw StateError('behavior check failed: mock datasource returned '
        'unexpected entity: \$product');
  }
  final list = await dataSource.getList(const ListQueryParams<Product>());
  if (list.length != 3) {
    throw StateError('behavior check failed: mock list size '
        '\${list.length} != 3');
  }
}
''');
        final run = await runBehaviorScript(fixture, script.path);
        expect(
          run.exitCode,
          0,
          reason:
              'generated mock datasource must EXECUTE (mock-first '
              'behavioral tier):\n${run.stdout}\n${run.stderr}',
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
          template: 'mock',
          generate: (root) async {
            final files =
                await MockPlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateMock: true,
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
