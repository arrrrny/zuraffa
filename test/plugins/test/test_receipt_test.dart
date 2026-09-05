import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/core/project/test_receipt.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/test/test_certifier.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Spec 980 / FR-003 + FR-004 — per-method test receipts.
///
/// Every entity test generation writes `.zfa/receipts/test-<entity>.json`
/// mapping each generated test to its usecase method + covered acceptance
/// path; `zfa proof check` (ProofChecker) re-derives the digests and flags
/// usecase/test drift.
void main() {
  late Directory workspace;
  late String projectRoot;
  late String outputDir;
  late FileSystem fs;

  final passAnalyzer = _PassAnalyzer();

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_receipt_');
    projectRoot = workspace.path;
    outputDir = path.join(projectRoot, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(path.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: receipt_app
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
    await write('data/mock/product_mock_data.dart', 'class ProductMockData {}');
    await write(
      'domain/repositories/data_product_repository.dart',
      'class DataProductRepository {}',
    );
  }

  group('TestReceiptStore round-trip (U8)', () {
    test('write -> load preserves per-test entries', () async {
      final store = TestReceiptStore(projectRoot: projectRoot);
      final receipt = TestReceipt(
        entity: 'Product',
        command: 'zfa test create --name Product',
        at: DateTime.utc(2026, 9, 5, 12, 0),
        tests: [
          TestReceiptEntry(
            name: 'should call repository.get and return result',
            testPath:
                'test/domain/usecases/product/get_product_usecase_test.dart',
            method: 'get',
            acceptancePath: 'success',
            testSha256: 'deadbeef',
            useCasePath:
                'lib/src/domain/usecases/product/get_product_usecase.dart',
            useCaseSha256: 'cafebabe',
          ),
          TestReceiptEntry(
            name: 'should return Failure when repository throws',
            testPath:
                'test/domain/usecases/product/get_product_usecase_test.dart',
            method: 'get',
            acceptancePath: 'failure',
            testSha256: 'deadbeef',
            useCasePath:
                'lib/src/domain/usecases/product/get_product_usecase.dart',
            useCaseSha256: 'cafebabe',
          ),
        ],
      );

      await store.write(receipt);
      final receiptFile = File(
        path.join(projectRoot, '.zfa', 'receipts', 'test-product.json'),
      );
      expect(
        receiptFile.existsSync(),
        isTrue,
        reason: 'named test-<entity>.json',
      );

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.schema, 'test.v1');
      expect(loaded.single.entity, 'Product');
      expect(loaded.single.tests, hasLength(2));
      expect(loaded.single.tests.first.method, 'get');
      expect(loaded.single.tests.first.acceptancePath, 'success');
      expect(loaded.single.tests.last.acceptancePath, 'failure');
      expect(loaded.single.tests.first.useCasePath, isNotNull);
      expect(loaded.single.tests.first.testSha256, 'deadbeef');
    });

    test('corrupted test receipts are skipped, not fatal', () async {
      final dir = Directory(path.join(projectRoot, '.zfa', 'receipts'));
      await dir.create(recursive: true);
      await File(
        path.join(dir.path, 'test-broken.json'),
      ).writeAsString('{not json');
      final store = TestReceiptStore(projectRoot: projectRoot);
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('generation writes the per-method receipt (A4/U9)', () {
    test(
      'entity generation maps every generated test to method + path',
      () async {
        await writeEntityFixtures();

        final plugin = TestPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
          fileSystem: fs,
          certifier: TestSelfCertifier(analyzer: passAnalyzer),
        );
        await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            repo: 'Product',
            outputDir: outputDir,
            generateTest: true,
            force: true,
          ),
        );

        final receiptFile = File(
          path.join(projectRoot, '.zfa', 'receipts', 'test-product.json'),
        );
        expect(receiptFile.existsSync(), isTrue);
        final receipt = TestReceipt.fromJson(
          jsonDecode(await receiptFile.readAsString()) as Map<String, dynamic>,
        );

        expect(receipt.schema, 'test.v1');
        expect(receipt.entity, 'Product');
        expect(
          receipt.tests,
          hasLength(2),
          reason: 'success + failure test entries',
        );

        final success = receipt.tests.firstWhere(
          (e) => e.acceptancePath == 'success',
        );
        final failure = receipt.tests.firstWhere(
          (e) => e.acceptancePath == 'failure',
        );

        expect(success.method, 'get');
        expect(failure.method, 'get');
        expect(success.name, 'should call repository.get and return result');
        expect(failure.name, 'should return Failure when repository throws');

        // The receipt binds the test to the usecase source with digests of
        // the exact bytes on disk.
        expect(
          success.useCasePath,
          'lib/src/domain/usecases/product/get_product_usecase.dart',
        );
        final usecaseFile = File(path.join(projectRoot, success.useCasePath!));
        final digest = crypto.sha256
            .convert(await usecaseFile.readAsBytes())
            .toString();
        expect(success.useCaseSha256, digest);

        final testFile = File(path.join(projectRoot, success.testPath));
        expect(testFile.existsSync(), isTrue);
        final testDigest = crypto.sha256
            .convert(await testFile.readAsBytes())
            .toString();
        expect(success.testSha256, testDigest);
        expect(failure.testSha256, testDigest);
      },
    );
  });

  group('proof check drift detection (A5/A6, U10-U12)', () {
    test(
      'U10 — ReceiptStore.loadAll skips test-*.json (separate kind)',
      () async {
        final store = TestReceiptStore(projectRoot: projectRoot);
        await store.write(
          TestReceipt(
            entity: 'Product',
            command: 'zfa test create --name Product',
            at: DateTime.utc(2026, 9, 5),
            tests: [
              TestReceiptEntry(
                name: 'should succeed',
                testPath: 'test/x_test.dart',
                method: 'get',
                acceptancePath: 'success',
                testSha256: 'a',
                useCasePath: 'lib/src/x.dart',
                useCaseSha256: 'b',
              ),
            ],
          ),
        );
        // The generic proof.v1 store must not try to parse test receipts.
        expect(await ReceiptStore(projectRoot: projectRoot).loadAll(), isEmpty);
      },
    );

    test('A6 — unchanged pair stays green', () async {
      await writeEntityFixtures();
      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        certifier: TestSelfCertifier(analyzer: passAnalyzer),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      final report = await ProofChecker(projectRoot: projectRoot).check();
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindStaleUsecase),
        isEmpty,
      );
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindModified),
        isEmpty,
      );
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindDeleted),
        isEmpty,
      );
    });

    test('A5/U12 — drifted usecase is flagged as stale_usecase', () async {
      await writeEntityFixtures();
      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        certifier: TestSelfCertifier(analyzer: passAnalyzer),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      // Drift: edit the usecase AFTER the tests were generated.
      await File(
        path.join(
          projectRoot,
          'lib',
          'src',
          'domain',
          'usecases',
          'product',
          'get_product_usecase.dart',
        ),
      ).writeAsString('class GetProductUseCase { void newMethod() {} }\n');

      final report = await ProofChecker(projectRoot: projectRoot).check();
      final drift = report.findings
          .where((f) => f.kind == ProofFinding.kindStaleUsecase)
          .toList();
      expect(drift, isNotEmpty, reason: 'usecase/test drift must be flagged');
      expect(drift.first.path, contains('get_product_usecase.dart'));
      expect(drift.first.detail, contains('get_product_usecase_test.dart'));
      expect(report.ok, isFalse);
    });

    test('U11 — deleted receipted test file is flagged', () async {
      await writeEntityFixtures();
      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        certifier: TestSelfCertifier(analyzer: passAnalyzer),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      await File(
        path.join(
          projectRoot,
          'test',
          'domain',
          'usecases',
          'product',
          'get_product_usecase_test.dart',
        ),
      ).delete();

      final report = await ProofChecker(projectRoot: projectRoot).check();
      final deleted = report.findings
          .where(
            (f) =>
                f.kind == ProofFinding.kindDeleted &&
                f.path.contains('get_product_usecase_test.dart'),
          )
          .toList();
      expect(deleted, isNotEmpty);
      expect(report.ok, isFalse);
    });

    test('U11 — tampered receipted test file is flagged as modified', () async {
      await writeEntityFixtures();
      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        certifier: TestSelfCertifier(analyzer: passAnalyzer),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          repo: 'Product',
          outputDir: outputDir,
          generateTest: true,
          force: true,
        ),
      );

      await File(
        path.join(
          projectRoot,
          'test',
          'domain',
          'usecases',
          'product',
          'get_product_usecase_test.dart',
        ),
      ).writeAsString('// hand edit\n');

      final report = await ProofChecker(projectRoot: projectRoot).check();
      final modified = report.findings
          .where(
            (f) =>
                f.kind == ProofFinding.kindModified &&
                f.path.contains('get_product_usecase_test.dart'),
          )
          .toList();
      expect(modified, isNotEmpty);
      expect(report.ok, isFalse);
    });
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
