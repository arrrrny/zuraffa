import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/test/test_certifier.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';

/// Spec 980 / FR-005 — direct `TestPlugin.generate` dispatch suite.
///
/// The plugin's dispatch (entity vs orchestrator vs polymorphic vs custom,
/// `test_plugin.dart` generate()) was previously unexercised by any direct
/// test. This suite drives each path directly and asserts the produced
/// files plus the 980 self-certification/receipt side effects.
void main() {
  late Directory workspace;
  late String projectRoot;
  late String outputDir;
  late FileSystem fs;

  final passAnalyzer = _PassAnalyzer();

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_dispatch_');
    projectRoot = workspace.path;
    outputDir = path.join(projectRoot, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(path.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: dispatch_app
environment:
  sdk: ^3.11.0
''');
    fs = FileSystem.create(root: projectRoot);
  });

  tearDown(() async {
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  });

  Future<void> write(String relativeToSrc, String content) async {
    final file = File(path.join(outputDir, relativeToSrc));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  TestPlugin plugin() => TestPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(force: true),
    fileSystem: fs,
    certifier: TestSelfCertifier(analyzer: passAnalyzer),
  );

  group('entity dispatch (isEntityBased)', () {
    Future<void> writeEntityFixtures() async {
      await write(
        'domain/entities/product/product.dart',
        'class Product { final String uuid; const Product({required this.uuid}); }',
      );
      await write(
        'domain/repositories/product_repository.dart',
        'abstract class ProductRepository {}',
      );
      await write(
        'domain/usecases/product/get_product_usecase.dart',
        'class GetProductUseCase {}',
      );
      await write(
        'data/datasources/product/product_datasource.dart',
        'abstract class ProductDataSource {}',
      );
      await write(
        'data/datasources/product/product_mock_datasource.dart',
        'class ProductMockDataSource {}',
      );
      await write(
        'data/mock/product_mock_data.dart',
        'class ProductMockData {}',
      );
      await write(
        'domain/repositories/data_product_repository.dart',
        'class DataProductRepository {}',
      );
    }

    test(
      'routes each valid method to generateForMethod (A7/A8 context)',
      () async {
        await writeEntityFixtures();
        await write(
          'domain/usecases/product/update_product_usecase.dart',
          'class UpdateProductUseCase {}',
        );
        await write(
          'domain/usecases/product/delete_product_usecase.dart',
          'class DeleteProductUseCase {}',
        );

        final files = await plugin().generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update', 'delete'],
            repo: 'Product',
            outputDir: outputDir,
            generateTest: true,
            force: true,
          ),
        );

        expect(files, hasLength(3));
        final names = files.map((f) => path.basename(f.path)).toSet();
        expect(names, {
          'get_product_usecase_test.dart',
          'update_product_usecase_test.dart',
          'delete_product_usecase_test.dart',
        });
        for (final file in files) {
          expect(file.action, isNot('skipped'));
          expect(file.content, contains('ThrowingProductDataSource'));
        }
      },
    );

    test('ignores methods outside the valid dispatch list', () async {
      await writeEntityFixtures();

      final files = await plugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'nonsense-method'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      expect(files, hasLength(1));
      expect(path.basename(files.single.path), 'get_product_usecase_test.dart');
    });

    test('self-certifies and writes a per-method receipt (A2/A4)', () async {
      await writeEntityFixtures();

      final p = plugin();
      await p.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      expect(p.lastCertification, isNotNull);
      expect(p.lastCertification!.compile, isTrue);
      expect(
        p.lastCertification!.tests,
        2,
        reason: 'success + failure per method',
      );

      final receipt = File(
        path.join(projectRoot, '.zfa', 'receipts', 'test-product.json'),
      );
      expect(receipt.existsSync(), isTrue, reason: 'per-entity test receipt');
    });
  });

  group('orchestrator dispatch (isOrchestrator)', () {
    test('A8 — generate routes to generateOrchestrator', () async {
      await write(
        'domain/usecases/checkout/process_checkout_usecase.dart',
        'class ProcessCheckoutUseCase {}',
      );
      await write(
        'domain/usecases/checkout/validate_cart_usecase.dart',
        'class ValidateCartUseCase {}',
      );
      await write(
        'domain/usecases/checkout/create_order_usecase.dart',
        'class CreateOrderUseCase {}',
      );

      final files = await plugin().generate(
        GeneratorConfig(
          name: 'ProcessCheckout',
          usecases: const ['ValidateCart', 'CreateOrder'],
          domain: 'checkout',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      expect(files, hasLength(1));
      final file = files.single;
      expect(path.basename(file.path), 'process_checkout_usecase_test.dart');
      expect(file.action, isNot('skipped'));
      expect(file.content, contains('class FakeValidateCartUseCase'));
      expect(file.content, contains('class FakeCreateOrderUseCase'));
      expect(file.content, contains('should orchestrate all usecases'));
    });
  });

  group('polymorphic dispatch (isPolymorphic)', () {
    test(
      'A9 — generate routes to generatePolymorphic (one file per variant)',
      () async {
        await write(
          'domain/usecases/payment/payment_fast_usecase.dart',
          'class PaymentFastUseCase {}',
        );
        await write(
          'domain/usecases/payment/payment_slow_usecase.dart',
          'class PaymentSlowUseCase {}',
        );
        await write(
          'domain/repositories/payment_repository.dart',
          'abstract class PaymentRepository {}',
        );

        final files = await plugin().generate(
          GeneratorConfig(
            name: 'Payment',
            variants: const ['Fast', 'Slow'],
            repo: 'Payment',
            domain: 'payment',
            outputDir: outputDir,
            generateTest: true,
            force: true,
          ),
        );

        expect(files, hasLength(2), reason: 'one test file per variant');
        final names = files.map((f) => path.basename(f.path)).toSet();
        expect(names, {
          'payment_fast_usecase_test.dart',
          'payment_slow_usecase_test.dart',
        });
        for (final file in files) {
          expect(file.action, isNot('skipped'));
          expect(file.content, contains('class FakePaymentRepository'));
        }
      },
    );
  });

  group('custom dispatch (isCustomUseCase)', () {
    test(
      'generate routes to generateCustom when no entity/variants/usecases',
      () async {
        await write(
          'domain/usecases/example/search_usecase.dart',
          'class SearchUseCase {}',
        );
        await write(
          'domain/repositories/sample_repository.dart',
          'abstract class SampleRepository {}',
        );

        final files = await plugin().generate(
          GeneratorConfig(
            name: 'Search',
            repo: 'Sample',
            domain: 'example',
            noEntity: true,
            outputDir: outputDir,
            generateTest: true,
            force: true,
          ),
        );

        expect(files, hasLength(1));
        final file = files.single;
        expect(path.basename(file.path), 'search_usecase_test.dart');
        expect(file.action, isNot('skipped'));
        expect(file.content, contains('class FakeSampleRepository'));
      },
    );
  });

  group('dispatch guards and delegation', () {
    test('U16 — returns no files when generateTest is false', () async {
      final files = await plugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          outputDir: outputDir,
          generateTest: false,
          force: true,
        ),
      );
      expect(files, isEmpty);
    });

    test(
      'U16 — a different config output dir delegates to a reconfigured plugin',
      () async {
        await write(
          'domain/usecases/example/search_usecase.dart',
          'class SearchUseCase {}',
        );
        await write(
          'domain/repositories/sample_repository.dart',
          'abstract class SampleRepository {}',
        );

        // Plugin anchored at lib/src, config points at the same tree through
        // an equivalent (different-string) output dir: the delegation branch
        // runs and still produces the file.
        final files = await plugin().generate(
          GeneratorConfig(
            name: 'Search',
            repo: 'Sample',
            domain: 'example',
            noEntity: true,
            outputDir: path.canonicalize(outputDir),
            generateTest: true,
            force: true,
          ),
        );

        expect(files, hasLength(1));
        expect(files.single.content, contains('FakeSampleRepository'));
      },
    );

    test(
      'dry-run generation certifies nothing and writes no receipt (U5)',
      () async {
        await write(
          'domain/usecases/example/search_usecase.dart',
          'class SearchUseCase {}',
        );
        await write(
          'domain/repositories/sample_repository.dart',
          'abstract class SampleRepository {}',
        );

        final p = plugin();
        await p.generate(
          GeneratorConfig(
            name: 'Search',
            repo: 'Sample',
            domain: 'example',
            noEntity: true,
            outputDir: outputDir,
            generateTest: true,
            force: true,
            dryRun: true,
          ),
        );

        expect(p.lastCertification, isNull);
        expect(
          File(
            path.join(projectRoot, '.zfa', 'receipts', 'test-search.json'),
          ).existsSync(),
          isFalse,
        );
      },
    );
  });
}

class _PassAnalyzer implements ScopedAnalyzer {
  @override
  Future<ScopedAnalysisResult> analyzeFile(
    String projectRoot,
    String filePath,
  ) async {
    return const ScopedAnalysisResult(ran: true, errors: []);
  }
}
