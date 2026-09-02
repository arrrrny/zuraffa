@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

/// Issue #807 — proof-carrying generation, v0 slice.
///
/// A real `zfa make` run persists a generation receipt into
/// `.zfa/receipts/` binding every file it wrote to the final on-disk
/// digest, plus the entity spec it was generated from.
void main() {
  late Directory workspace;
  late String outputDir;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_receipt_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_receipt_test
environment:
  sdk: ^3.11.0
''');
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

  test('a real make run ships a receipt with per-file digests and the '
      'entity spec binding', () async {
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Product',
      'usecase',
      '--output',
      outputDir,
    ]);

    expect(
      output,
      isNot(contains('❌ Error')),
      reason:
          'generation must succeed for the receipt test to be '
          'meaningful:\n$output',
    );

    final store = ReceiptStore(projectRoot: workspace.path);
    final all = await store.loadAll();
    expect(
      all,
      hasLength(1),
      reason: 'exactly one receipt for the single make run',
    );

    final receipt = all.single.receipt;
    expect(receipt.schema, 'proof.v1');
    expect(receipt.command, 'make');
    expect(receipt.target, 'Product');
    expect(receipt.repro, contains('zfa make Product'));
    expect(receipt.generatorVersion, isNotEmpty);

    // The usecase the run generated must be covered by digest.
    final usecase = receipt.files.where(
      (f) => f.path.endsWith('get_product_usecase.dart'),
    );
    expect(
      usecase,
      hasLength(1),
      reason: 'receipt files: ${receipt.files.map((f) => f.path)}',
    );
    final disk = File(p.join(workspace.path, usecase.single.path));
    expect(disk.existsSync(), isTrue);
    expect(
      usecase.single.sha256,
      crypto.sha256.convert(disk.readAsBytesSync()).toString(),
    );

    // Spec binding: the entity the run consumed, by digest.
    expect(receipt.spec, isNotNull);
    expect(receipt.spec!.path, 'lib/src/domain/entities/product/product.dart');
    expect(
      receipt.spec!.sha256,
      crypto.sha256
          .convert(
            File(p.join(workspace.path, receipt.spec!.path)).readAsBytesSync(),
          )
          .toString(),
    );

    // And the freshly generated project must verify green end-to-end.
    final proofOutput = await runner.runCapturing([
      '-C',
      workspace.path,
      'proof',
      'check',
      '--format=json',
    ]);
    // `proof check` is asserted thoroughly in proof_command_test; here we
    // only assert the driver can consume what make just produced.
    expect(
      proofOutput,
      contains('"ok":true'),
      reason: 'fresh generation must be provable:\n$proofOutput',
    );
    final proofJson = jsonDecode(proofOutput) as Map<String, dynamic>;
    expect(proofJson['ok'], isTrue);
    expect(
      proofJson['findings'],
      isEmpty,
      reason: 'a fresh generation must verify with zero findings',
    );
  });

  test('dry-run and revert runs do not ship receipts', () async {
    await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Product',
      'usecase',
      '--dry-run',
      '--output',
      outputDir,
    ]);

    final all = await ReceiptStore(projectRoot: workspace.path).loadAll();
    expect(
      all,
      isEmpty,
      reason: 'nothing was written, so there is nothing to prove',
    );
  });
}
