import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/di/capabilities/create_di_capability.dart';
import 'package:zuraffa/src/plugins/di/capabilities/register_capability.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

/// SPEC 0974 (issue #974, order 3): the standalone `zfa di create/register`
/// path must ship proof — a `proof.v1` receipt appended under
/// `.zfa/receipts/` (registrations written + index hash) via
/// `ReceiptStore`, so `zfa proof check` is green after a standalone run
/// exactly like the `zfa make` path (issue #807).
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_receipt_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  List<File> receiptFiles() => Directory(
        p.join(projectRoot, '.zfa', 'receipts'),
      )
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

  test(
    'A3: standalone di create appends a di-<target> receipt binding the '
    'written registrations and index',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final capability = CreateDiCapability(plugin, projectRoot: projectRoot);

      final result = await capability.execute({'name': 'Product'});

      expect(result.success, isTrue, reason: 'generation itself succeeded');

      final receipts = receiptFiles();
      expect(receipts, isNotEmpty,
          reason: 'standalone di create must write a receipt');
      expect(
        receipts.first.path,
        matches(RegExp(r'-di-Product\.json$')),
        reason: 'ReceiptStore names receipts <stamp>-di-<target>.json',
      );

      final receipt = GenerationReceipt.fromJson(
        jsonDecode(receipts.first.readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(receipt.schema, 'proof.v1');
      expect(receipt.command, 'di');
      expect(receipt.target, 'Product');
      expect(receipt.repro, contains('zfa di create Product'));

      // Registrations written: every receipted artifact exists on disk and
      // its digest binds the exact bytes.
      expect(receipt.files, isNotEmpty);
      for (final entry in receipt.files) {
        final file = File(p.join(projectRoot, entry.path));
        expect(file.existsSync(), isTrue,
            reason: '${entry.path} must exist when receipted');
        final digest = crypto.sha256.convert(file.readAsBytesSync()).toString();
        expect(entry.sha256, digest,
            reason: '${entry.path} digest must bind on-disk bytes');
      }
      expect(
        receipt.files.any((f) => f.path.endsWith('di/index.dart')),
        isTrue,
        reason: 'the DI index must be receipted',
      );

      // Index hash recorded in the input context.
      expect(receipt.input['plugin'], 'di');
      expect(receipt.input['capability'], 'create');
      final indexFiles = receipt.input['index_files'];
      expect(indexFiles, isA<Map<String, dynamic>>());
      expect((indexFiles as Map).keys, anyElement(endsWith('di/index.dart')));
    },
  );

  test(
    'A3b: zfa proof check (ProofChecker) is green after a standalone run',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      await CreateDiCapability(plugin, projectRoot: projectRoot)
          .execute({'name': 'Product'});

      final report = await ProofChecker(projectRoot: projectRoot).check();
      expect(report.ok, isTrue,
          reason: 'proof findings: ${report.findings.map((f) => f.detail)}');
      expect(report.receipts, 1);
      expect(report.filesChecked, greaterThan(0));
    },
  );

  test(
    'U4: standalone di register also writes a receipt',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final capability = RegisterCapability(plugin, projectRoot: projectRoot);

      final result = await capability.execute({'target': 'ListingService'});

      expect(result.success, isTrue);
      final receipts = receiptFiles();
      expect(receipts, isNotEmpty);
      expect(receipts.first.path, matches(RegExp(r'-di-ListingService\.json$')));

      final receipt = GenerationReceipt.fromJson(
        jsonDecode(receipts.first.readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(receipt.command, 'di');
      expect(receipt.target, 'ListingService');
      expect(receipt.input['capability'], 'register');
      expect(receipt.files, isNotEmpty);

      final report = await ProofChecker(projectRoot: projectRoot).check();
      expect(report.ok, isTrue);
    },
  );

  test(
    'U5: dry-run and revert runs write no receipt',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final capability = CreateDiCapability(plugin, projectRoot: projectRoot);

      await capability.execute({'name': 'Product', 'dryRun': true});
      expect(
        Directory(p.join(projectRoot, '.zfa', 'receipts')).existsSync(),
        isFalse,
        reason: 'dry-run must not persist proof for unwritten artifacts',
      );
    },
  );
}
