// Bug 1198 (part of #908 P0) — template self-hosting: `usecase` template.
//
// Drives the usecase template through the TDD loop against the shared
// fixture entity (Product, #1198 harness): structural + compile +
// behavioral tiers (the #1117/spec-1003 bar) plus the byte-stability diff
// guard with a determinism receipt.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture(
      'usecase',
      repoRoot,
      withRepository: true,
    );
    bare = await createTempFixture('usecase_bare');
    await writeFixtureEntity(bare, withRepository: true);
  });

  tearDownAll(() async {
    if (fixture.existsSync()) fixture.delete(recursive: true);
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final files =
        await UseCasePlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits one usecase per method at the canonical paths', () async {
      final files = await generateInto(bare);
      expect(files, hasLength(2));
      final paths = files.map((f) => f.path).toSet();
      expect(
        paths,
        containsAll(<Matcher>[
          contains('domain/usecases/product/get_product_usecase.dart'),
          contains('domain/usecases/product/get_product_list_usecase.dart'),
        ]),
      );
    });

    test(
      'declares the fixture-entity contract (class, extends, execute)',
      () async {
        final files = await generateInto(bare);
        final getContent = files
            .firstWhere((f) => f.path.contains('get_product_usecase.dart'))
            .content!;
        expect(getContent, contains('class GetProductUseCase'));
        expect(getContent, contains('UseCase<Product, QueryParams<Product>>'));
        expect(getContent, contains('Future<Product> execute'));
        expect(getContent, contains("import 'package:zuraffa/zuraffa.dart'"));
      },
    );
  });

  group('compile', () {
    test('generated usecases analyze clean in the pure-Dart fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'usecases');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test('generated usecase executes and returns the fixture entity', () async {
      await generateInto(fixture);

      final script = File(p.join(fixture.path, 'tool', 'behavior_check.dart'));
      await script.parent.create(recursive: true);
      await script.writeAsString('''
// Bug 1198 behavioral tier — executes the GENERATED usecase against a
// stub repository returning the fixture entity. Fails the loop when the
// template emits code that compiles but cannot run.
import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/domain/repositories/product_repository.dart';
import '../lib/src/domain/usecases/product/get_product_usecase.dart';

class StubProductRepository implements ProductRepository {
  @override
  Future<Product> get(QueryParams<Product> params) async {
    return Product(
      id: 'p1',
      name: 'Desk',
      price: 99.5,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<Product> create(Product product) => throw UnimplementedError();

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) =>
      throw UnimplementedError();

  @override
  Future<Product> update(UpdateParams<String, Product> params) =>
      throw UnimplementedError();

  @override
  Future<void> delete(DeleteParams<String> params) =>
      throw UnimplementedError();
}

Future<void> main() async {
  final useCase = GetProductUseCase(StubProductRepository());
  final result = await useCase(const QueryParams<Product>());
  if (!result.isSuccess) {
    throw StateError('behavior check failed: generated usecase returned '
        'a failure for the fixture entity');
  }
  final product = (result as Success<Product, AppFailure>).value;
  if (product.id != 'p1' || product.name != 'Desk') {
    throw StateError('behavior check failed: wrong entity emitted: '
        '\$product');
  }
}
''');
      final run = await runBehaviorScript(fixture, script.path);
      expect(
        run.exitCode,
        0,
        reason:
            'generated usecase must EXECUTE (behavioral tier):\n'
            '${run.stdout}\n${run.stderr}',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'usecase',
          generate: (root) async {
            final files =
                await UseCasePlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
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
