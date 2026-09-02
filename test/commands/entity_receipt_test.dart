import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/core/project/receipt_store.dart';

import '../helpers/run_zfa_source.dart';

/// Issue #807 — proof-carrying generation, v0 slice.
///
/// `zfa entity create` (and every entity mutation it ships with, e.g.
/// `add-field`) must emit a generation receipt into `.zfa/receipts/` binding
/// the written file to its final content digest, so `zfa proof check` can
/// later prove where the artifact came from.
///
/// Driven through a real subprocess ([runZfaSource]): `entity` calls
/// `exit()` on its error paths, and a subprocess keeps the process-global
/// `Directory.current` (which `-C` mutates) fully hermetic under parallel
/// `dart test` (issue #506 pattern).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_entity_receipt_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_entity_receipt_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
  });

  tearDown(() {
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  String digestOf(String relativePath) => crypto.sha256
      .convert(File(p.join(workspace.path, relativePath)).readAsBytesSync())
      .toString();

  Future<List<ReceiptRecord>> receipts() =>
      ReceiptStore(projectRoot: workspace.path).loadAll();

  group('entity create receipt emission', () {
    test('creates a receipt binding the entity file to its digest', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Product',
        '--fields',
        'name:String',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('✓ Created entity'));

      final entityPath = 'lib/src/domain/entities/product/product.dart';
      expect(File(p.join(workspace.path, entityPath)).existsSync(), isTrue);

      final all = await receipts();
      expect(all, hasLength(1), reason: 'exactly one generation receipt');

      final receipt = all.single.receipt;
      expect(receipt.schema, 'proof.v1');
      expect(receipt.command, 'entity create');
      expect(receipt.target, 'Product');
      expect(receipt.repro, contains('zfa entity create'));
      expect(receipt.generatorVersion, isNotEmpty);

      final covered = receipt.files
          .where((f) => f.path == entityPath)
          .toList(growable: false);
      expect(covered, hasLength(1));
      expect(
        covered.single.sha256,
        digestOf(entityPath),
        reason: 'receipt digest must match the bytes actually on disk',
      );
      expect(covered.single.action, 'create');
    });

    test('add-field emits a newer receipt whose digest wins', () async {
      final create = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Product',
        '--fields',
        'name:String',
      ], workingDirectory: workspace.path);
      expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');

      final addField = await runZfaSource([
        'entity',
        'add-field',
        '-n',
        'Product',
        '--field',
        'price:double',
      ], workingDirectory: workspace.path);
      expect(addField.exitCode, 0, reason: 'stdout=${addField.stdout}');
      expect(addField.stdout, contains('✓ Added 1 field(s) to Product'));

      final entityPath = 'lib/src/domain/entities/product/product.dart';
      final all = await receipts();
      expect(
        all.length,
        2,
        reason: 'create + add-field each ship their own receipt',
      );

      final latest = ReceiptStore.latestForPath(all, entityPath);
      expect(latest, isNotNull);
      expect(latest!.record.receipt.command, 'entity add-field');
      expect(
        latest.entry.sha256,
        digestOf(entityPath),
        reason: 'the newest receipt must bind the CURRENT bytes',
      );
    });
  });
}
