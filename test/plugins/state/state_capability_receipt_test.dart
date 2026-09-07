// Spec 1126 (order 2) — receipts on the state capability + CLI path.
//
// `CreateStateCapability.execute()` must ship a `proof.v1` receipt (the
// same shape cache/route/tdd/service use) at
// `.zfa/receipts/state-<entity>.json`, binding the state file's sha256
// AND the entity source hash, so `zfa state verify` has a contract to
// audit against. The CLI path (`zfa state create`) must produce the
// same stable document (AC-3), additively to its existing timestamped
// issue-#1138 receipt.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/state/capabilities/create_state_capability.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

void main() {
  late Directory workspace;
  late StatePlugin plugin;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_state_rcpt_');
    // A pure-Dart pubspec pins the flavor (#512) so generation succeeds.
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: state_receipt_ws
publish_to: none
environment:
  sdk: ^3.11.0
''');
    plugin = StatePlugin(outputDir: p.join(workspace.path, 'lib', 'src'));
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  /// The entity source the receipt must bind (state files are generated
  /// FROM an entity; the entity hash is the stale-detection anchor).
  Future<void> seedEntity() async {
    final entityDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  const Product({required this.id});
}
''');
  }

  test('SC-1126-a: capability execute writes the stable per-entity receipt '
      'with proof.v1 + state_sha256 + entity_source', () async {
    await seedEntity();
    final capability = CreateStateCapability(
      plugin,
      projectRoot: workspace.path,
    );
    final result = await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
      'force': true,
    });

    expect(result.success, isTrue, reason: '${result.message}');

    final receiptPath = result.data?['stateReceipt'] as String?;
    expect(receiptPath, isNotNull, reason: 'the receipt path rides data');
    expect(
      receiptPath,
      endsWith('.zfa/receipts/state-product.json'),
      reason:
          'the stable per-entity name the issue pins (snake, '
          'datasource-ledger convention)',
    );
    expect(File(receiptPath!).existsSync(), isTrue);

    final doc =
        jsonDecode(File(receiptPath).readAsStringSync())
            as Map<String, dynamic>;
    final receipt = GenerationReceipt.fromJson(doc);
    expect(receipt.schema, 'proof.v1');
    expect(receipt.command, 'state create');
    expect(receipt.plugin, 'state');
    expect(receipt.capability, 'create');
    expect(receipt.entity, 'Product');
    expect(receipt.files, hasLength(1));

    // The state file's sha256 — the digest binding the verify gate
    // checks the CURRENT bytes against.
    final entry = receipt.files.single;
    expect(entry.path, 'lib/src/presentation/pages/product/product_state.dart');
    final stateOnDisk = File(p.join(workspace.path, entry.path));
    expect(stateOnDisk.existsSync(), isTrue);
    expect(
      entry.sha256,
      crypto.sha256.convert(stateOnDisk.readAsBytesSync()).toString(),
      reason: 'the receipt digests the final on-disk bytes',
    );
    expect(doc['state_sha256'], entry.sha256);

    // The entity source hash — the spec the state was generated FROM.
    final entitySource = doc['entity_source'] as Map<String, dynamic>?;
    expect(entitySource, isNotNull, reason: 'the entity file exists');
    expect(
      entitySource!['path'],
      'lib/src/domain/entities/product/product.dart',
    );
    final entityOnDisk = File(p.join(workspace.path, entitySource['path']));
    expect(
      entitySource['sha256'],
      crypto.sha256.convert(entityOnDisk.readAsBytesSync()).toString(),
    );

    // The ledger data the verify gate + explain surface read.
    expect(doc['state_class'], 'ProductState');
    expect(doc['methods'], containsAll(<String>['get', 'getList']));
  });

  test('SC-1126-b: no entity file → the receipt still ships (entity_source '
      'honestly absent, not faked)', () async {
    final capability = CreateStateCapability(
      plugin,
      projectRoot: workspace.path,
    );
    final result = await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
      'force': true,
    });
    expect(result.success, isTrue);

    final doc =
        jsonDecode(
              File(result.data!['stateReceipt'] as String).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(doc['entity_source'], isNull);
    expect(doc['state_sha256'], isNotNull);
  });

  test('SC-1126-c: dry runs never persist proofs', () async {
    final capability = CreateStateCapability(
      plugin,
      projectRoot: workspace.path,
    );
    final result = await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
      'dryRun': true,
    });
    expect(result.success, isTrue);
    expect(result.data?['stateReceipt'], isNull);
    expect(
      Directory(p.join(workspace.path, '.zfa', 'receipts')).existsSync(),
      isFalse,
      reason: 'a dry run writes no receipts',
    );
  });

  test('SC-1126-d: the CLI path also produces .zfa/receipts/'
      'state-<entity>.json (AC-3), additively to the #1138 receipt', () async {
    await seedEntity();
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'state',
      'create',
      '--name',
      'Product',
      '--methods',
      'get,getList',
      '--json',
    ]);
    expect(output, isNot(contains('❌')), reason: output);

    final stable = File(
      p.join(workspace.path, '.zfa', 'receipts', 'state-product.json'),
    );
    expect(
      stable.existsSync(),
      isTrue,
      reason: 'AC-3: the stable receipt exists after zfa state create',
    );
    final doc = jsonDecode(stable.readAsStringSync()) as Map<String, dynamic>;
    expect(doc['schema'], 'proof.v1');
    expect(doc['state_class'], 'ProductState');

    // Additive: the timestamped issue-#1138 receipt still exists too.
    final receiptsDir = Directory(p.join(workspace.path, '.zfa', 'receipts'));
    expect(
      receiptsDir.listSync().whereType<File>().where(
        (f) => p.basename(f.path).startsWith('state-create-Product-'),
      ),
      hasLength(1),
      reason: 'the timestamped capability receipt is additive-kept',
    );
  });

  test('SC-1126-e: regeneration refreshes the stable receipt in place '
      '(latest-wins, no duplicate accumulation)', () async {
    await seedEntity();
    final capability = CreateStateCapability(
      plugin,
      projectRoot: workspace.path,
    );
    await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
      'force': true,
    });
    final stable = File(
      p.join(workspace.path, '.zfa', 'receipts', 'state-product.json'),
    );
    final firstDigest = crypto.sha256
        .convert(stable.readAsBytesSync())
        .toString();

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
      'force': true,
    });

    expect(stable.existsSync(), isTrue);
    final doc = jsonDecode(stable.readAsStringSync()) as Map<String, dynamic>;
    expect(
      crypto.sha256.convert(stable.readAsBytesSync()).toString(),
      isNot(firstDigest),
      reason: 'the document is refreshed (new `at` stamp)',
    );
    final stateOnDisk = File(
      p.join(workspace.path, doc['files'][0]['path'] as String),
    );
    expect(
      doc['state_sha256'],
      crypto.sha256.convert(stateOnDisk.readAsBytesSync()).toString(),
      reason: 'the refreshed digest binds the current bytes',
    );
  });
}
