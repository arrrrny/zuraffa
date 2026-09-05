import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

/// Issue #978, order 3 — make-triad end-to-end proof.
///
/// `zfa make <Entity> --service` is the documented service flow: the plan
/// resolver maps a present `--service` value to the triad
/// usecase + service + provider (plan_resolver.dart, unchanged by this
/// spec — tested, not rewired). Adding `di` activates the DI wiring.
///
/// This behavioral test proves, in a real temp project:
///   1. the service interface lands with real content,
///   2. the DI wiring for the service lands with real content,
///   3. the provider implementation lands with real content,
///   4. the run ships a proof.v1 receipt whose digest covers the service
///      artifact (issue #807 proof-carrying generation).
///
/// In-process (`CliRunner.runCapturing`) on purpose: no subprocess, no
/// `dart pub get`, no build_runner — safe for the fast tier and the
/// chunked cloud runner.
void main() {
  late Directory workspace;
  late String outputDir;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_service_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_service_triad_test
environment:
  sdk: ^3.11.0
''');
    // A minimal entity with a real identity field — make's id resolution
    // (issues #307/#508) requires it for the id-dependent triad.
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test(
    'zfa make <Entity> --service produces service interface + DI wiring + '
    'provider, with a proof receipt',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Product',
        '--service',
        'Product',
        'di',
        '--output',
        outputDir,
      ]);

      expect(
        output,
        isNot(contains('❌')),
        reason: 'the make run must succeed:\n$output',
      );

      // 1. Service interface — real content, entity-method signatures.
      final serviceFile = File(
        p.join(
          outputDir,
          'domain',
          'services',
          'product',
          'product_service.dart',
        ),
      );
      // Entity-based configs write under domain/services/<domain>/.
      final flatServiceFile = File(
        p.join(outputDir, 'domain', 'services', 'product_service.dart'),
      );
      final serviceContent =
          (serviceFile.existsSync() ? serviceFile : flatServiceFile)
              .readAsStringSync();
      expect(
        serviceContent,
        contains('abstract class ProductService'),
        reason: 'the service interface must be generated with real content',
      );
      expect(
        serviceContent,
        anyOf(contains('Future<Product>'), contains('getProduct')),
        reason: 'the interface must declare the entity method surface',
      );

      // 2. DI wiring for the service — registration content, not an empty
      //    stub.
      final serviceDi = File(
        p.join(outputDir, 'di', 'services', 'product_service_di.dart'),
      );
      expect(
        serviceDi.existsSync(),
        isTrue,
        reason:
            'DI wiring for the service must land '
            '(di/services/product_service_di.dart):\n$output',
      );
      final diContent = serviceDi.readAsStringSync();
      expect(diContent, contains('ProductService'));
      expect(
        diContent,
        anyOf(contains('register'), contains('registerLazySingleton')),
        reason: 'the DI file must register the service/provider pair',
      );

      // 3. Provider implementation — implements the service interface.
      final providersDir = Directory(p.join(outputDir, 'data', 'providers'));
      final providerFiles = providersDir.existsSync()
          ? providersDir
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('product_provider.dart'))
                .toList()
          : <File>[];
      expect(
        providerFiles,
        isNotEmpty,
        reason:
            'the provider implementation must land '
            '(data/providers/**/product_provider.dart):\n$output',
      );
      final providerContent = providerFiles.first.readAsStringSync();
      expect(providerContent, contains('class ProductProvider'));
      expect(
        providerContent,
        contains('implements ProductService'),
        reason: 'the provider must implement the generated service interface',
      );

      // 4. Receipt — the run is proof-carrying (#807): a proof.v1 receipt
      //    exists and its digest covers the service artifact.
      final store = ReceiptStore(projectRoot: workspace.path);
      final all = await store.loadAll();
      expect(all, isNotEmpty, reason: 'the make run must ship a receipt');

      final receipt = all.first.receipt;
      expect(receipt.schema, 'proof.v1');
      expect(receipt.command, 'make');
      expect(receipt.target, 'Product');
      expect(receipt.repro, contains('zfa make Product'));

      final serviceRelPath = serviceFile.existsSync()
          ? p.relative(serviceFile.path, from: workspace.path)
          : p.relative(flatServiceFile.path, from: workspace.path);
      final receiptEntry = receipt.files.where((f) => f.path == serviceRelPath);
      expect(
        receiptEntry,
        hasLength(1),
        reason:
            'the receipt must cover the service artifact by digest: '
            '${receipt.files.map((f) => f.path).toList()}',
      );
    },
  );

  test(
    'proof check verifies the freshly generated service triad green',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Product',
        '--service',
        'Product',
        'di',
        '--output',
        outputDir,
      ]);

      final proofOutput = await runner.runCapturing([
        '-C',
        workspace.path,
        'proof',
        'check',
        '--format=json',
      ]);
      final proofJson = jsonDecode(proofOutput) as Map<String, dynamic>;
      expect(
        proofJson['ok'],
        isTrue,
        reason: 'fresh triad generation must be provable:\n$proofOutput',
      );
    },
  );
}
