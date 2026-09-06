import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/plugins/datasource/capabilities/create_datasource_capability.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

/// Spec #1131 (order 2) — receipts from `CreateDataSourceCapability.execute()`.
///
/// The capability itself (not only the standalone positional command path)
/// must persist the deterministic proof.v1 receipt at
/// `.zfa/receipts/datasource-<entity>.json`, binding:
///   * every emitted artifact's digest (proof.v1 files[]), and
///   * the datasource INTERFACE's sha256 (`interface_sha256`), and
///   * the ENTITY source hash (`entity_source.sha256`) — the spec the
///     datasource was generated FROM, so later entity edits are detectable.
void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1131_receipt_');
    originalCwd = Directory.current.path;
    Directory.current = tempDir.path;
  });

  tearDown(() async {
    Directory.current = originalCwd;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  void writeEntity(String entityName, String source) {
    final snake = StringUtils.camelToSnake(entityName);
    final dir = Directory('${tempDir.path}/lib/src/domain/entities/$snake');
    dir.createSync(recursive: true);
    File('${dir.path}/$snake.dart').writeAsStringSync(source);
  }

  CreateDataSourceCapability capability() {
    final plugin = DataSourcePlugin(
      outputDir: '${tempDir.path}/lib/src',
      options: const GeneratorOptions(),
    );
    // The CLI derives the receipt root from the plugin outputDir; tests
    // pin it explicitly.
    return CreateDataSourceCapability(plugin, projectRoot: tempDir.path);
  }

  test(
    'capability execute writes datasource-<entity>.json with interface sha256 and entity source hash',
    () async {
      writeEntity(
        'Product',
        'class Product {\n'
            '  const Product({required this.id, required this.name});\n'
            '  final String id;\n'
            '  final String name;\n'
            '}\n',
      );

      final result = await capability().execute({
        'name': 'Product',
        'remote': true,
        'force': true,
      });
      expect(result.success, isTrue, reason: result.message);

      final receiptFile = File(
        '${tempDir.path}/.zfa/receipts/datasource-product.json',
      );
      expect(receiptFile.existsSync(), isTrue);

      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(receipt['schema'], 'proof.v1');

      // The datasource interface's sha256 is bound.
      final snake = StringUtils.camelToSnake('Product');
      final interfaceFile = File(
        '${tempDir.path}/lib/src/data/datasources/$snake/${snake}_datasource.dart',
      );
      expect(interfaceFile.existsSync(), isTrue);
      expect(
        receipt['interface_sha256'],
        sha256.convert(interfaceFile.readAsBytesSync()).toString(),
      );

      // The entity source hash is bound (path + digest).
      final entitySource = receipt['entity_source'] as Map<String, dynamic>;
      expect(entitySource['path'], contains('entities/product/product.dart'));
      final entityFile = File(
        '${tempDir.path}/lib/src/domain/entities/$snake/$snake.dart',
      );
      expect(
        entitySource['sha256'],
        sha256.convert(entityFile.readAsBytesSync()).toString(),
      );
    },
  );

  test('entity_source.sha256 is the digest of the entity file bytes', () async {
    writeEntity('Cart', 'class Cart {\n  final String id;\n}\n');
    final result = await capability().execute({
      'name': 'Cart',
      'remote': true,
      'force': true,
    });
    expect(result.success, isTrue);

    final receipt =
        jsonDecode(
              File(
                '${tempDir.path}/.zfa/receipts/datasource-cart.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final entitySource = receipt['entity_source'] as Map<String, dynamic>;
    final entityFile = File(
      '${tempDir.path}/lib/src/domain/entities/cart/cart.dart',
    );
    expect(
      entitySource['sha256'],
      sha256.convert(entityFile.readAsBytesSync()).toString(),
    );
  });

  test(
    'receipt keeps `proof check` green (artifact digests re-derive)',
    () async {
      writeEntity('Order', 'class Order {\n  final String id;\n}\n');
      final result = await capability().execute({
        'name': 'Order',
        'remote': true,
        'force': true,
      });
      expect(result.success, isTrue);

      final report = await ProofChecker(projectRoot: tempDir.path).check();
      expect(report.ok, isTrue, reason: '${report.findings}');
    },
  );

  test('dry run never writes a receipt', () async {
    final result = await capability().execute({
      'name': 'Product',
      'dryRun': true,
    });
    expect(result.success, isTrue);
    expect(Directory('${tempDir.path}/.zfa/receipts').existsSync(), isFalse);
  });

  test('skipped generation (no files) writes no receipt', () async {
    // hasService declines generation entirely — nothing receiptable.
    final result = await capability().execute({
      'name': 'Product',
      'useService': true,
    });
    expect(result.success, isFalse);
    expect(
      Directory('${tempDir.path}/.zfa/receipts').existsSync(),
      isFalse,
      reason: 'a declined run commits no bytes, so it receipts nothing',
    );
  });
}
