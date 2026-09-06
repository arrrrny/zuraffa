// Bug 1198 (part of #908 P0) — template self-hosting: `service` template.
//
// Full trust-tier loop against the fixture entity: structural + compile +
// behavioral + byte-stability diff guard (#1198 harness).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('service', repoRoot);
    bare = await createTempFixture('service_bare');
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
        await ServicePlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: 'GetProduct',
            methods: const [],
            service: 'Product',
            domain: 'product',
            paramsType: 'QueryParams<Product>',
            returnsType: 'Product',
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits the service interface at the canonical path', () async {
      final files = await generateInto(bare);
      expect(files, hasLength(1));
      expect(
        files.single.path,
        contains('domain/services/product_service.dart'),
      );
    });

    test('declares the fixture-entity contract', () async {
      final files = await generateInto(bare);
      final content = files.single.content!;
      expect(content, contains('abstract class ProductService'));
      expect(
        content,
        contains('Future<Product> getProduct(QueryParams<Product> params);'),
      );
      expect(content, contains("import '../entities/product/product.dart';"));
      expect(content, isNot(contains('UnimplementedError')));
    });
  });

  group('compile', () {
    test('generated service interface analyzes clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'service');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test('generated service contract is implementable and callable', () async {
      await generateInto(fixture);

      final script = File(p.join(fixture.path, 'tool', 'behavior_check.dart'));
      await script.parent.create(recursive: true);
      await script.writeAsString('''
// Bug 1198 behavioral tier — implements the GENERATED service interface
// and executes it. Fails the loop when the template emits a contract that
// cannot be satisfied or called.
import 'package:zuraffa/zuraffa.dart';

import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/domain/services/product_service.dart';

class StubProductService implements ProductService {
  @override
  Future<Product> getProduct(QueryParams<Product> params) async {
    return Product(
      id: 'p1',
      name: 'Desk',
      price: 99.5,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }
}

Future<void> main() async {
  final ProductService service = StubProductService();
  final product = await service.getProduct(const QueryParams<Product>());
  if (product.id != 'p1' || product.price != 99.5) {
    throw StateError('behavior check failed: wrong entity through the '
        'generated service contract');
  }
}
''');
      final run = await runBehaviorScript(fixture, script.path);
      expect(
        run.exitCode,
        0,
        reason:
            'generated service contract must be implementable and '
            'callable (behavioral tier):\n${run.stdout}\n${run.stderr}',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'service',
          generate: (root) async {
            final files =
                await ServicePlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: 'GetProduct',
                    methods: const [],
                    service: 'Product',
                    domain: 'product',
                    paramsType: 'QueryParams<Product>',
                    returnsType: 'Product',
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
