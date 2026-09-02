import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';

/// Writes [content] to a project-relative path inside [root] and returns the
/// receipt file entry that binds it.
Future<GenerationReceiptFile> seedFile(
  Directory root,
  String relativePath,
  String content, {
  String action = 'create',
  bool withSnapshot = true,
}) async {
  final file = File(p.join(root.path, relativePath));
  await file.create(recursive: true);
  await file.writeAsString(content);
  final bytes = file.readAsBytesSync();
  return GenerationReceiptFile(
    path: relativePath,
    action: action,
    sha256: crypto.sha256.convert(bytes).toString(),
    bytes: bytes.length,
    snapshot: withSnapshot ? content : null,
  );
}

void main() {
  late Directory workspace;
  late ReceiptStore store;
  late ProofChecker checker;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_proof_check_');
    store = ReceiptStore(projectRoot: workspace.path);
    checker = ProofChecker(projectRoot: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('ProofChecker', () {
    test('a project whose files match their receipts verifies green', () async {
      final entry = await seedFile(
        workspace,
        'lib/src/domain/entities/product/product.dart',
        'class Product {\n  final String id;\n}\n',
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'entity create',
          target: 'Product',
          repro: 'zfa entity create Product',
          at: DateTime.utc(2026, 9, 3, 10),
          generatorVersion: '6.1.0',
          input: const {},
          files: [entry],
        ),
      );

      final report = await checker.check();

      expect(report.ok, isTrue, reason: report.findings.toString());
      expect(report.receipts, 1);
      expect(report.filesChecked, 1);
      expect(report.findings, isEmpty);
    });

    test(
      'editing a generated file flips red with a precise line diff',
      () async {
        final original = 'class Product {\n  final String id;\n}\n';
        final entry = await seedFile(
          workspace,
          'lib/src/domain/entities/product/product.dart',
          original,
        );
        await store.save(
          GenerationReceipt(
            schema: 'proof.v1',
            command: 'entity create',
            target: 'Product',
            repro: 'zfa entity create Product',
            at: DateTime.utc(2026, 9, 3, 10),
            generatorVersion: '6.1.0',
            input: const {},
            files: [entry],
          ),
        );

        // A hand edit lands on the generated file.
        await File(p.join(workspace.path, entry.path)).writeAsString(
          'class Product {\n  final String id;\n  final String name;\n}\n',
        );

        final report = await checker.check();

        expect(report.ok, isFalse);
        final finding = report.findings.single;
        expect(finding.kind, 'modified');
        expect(finding.path, entry.path);
        expect(
          finding.diff,
          isNotNull,
          reason: 'small files carry a snapshot so check can show a diff',
        );
        expect(finding.diff!, contains('+   final String name;'));
        expect(
          finding.diff!,
          isNot(contains('-  final String id;')),
          reason: 'unchanged lines must not appear as removals',
        );
      },
    );

    test(
      'deleting a generated file flips red with the receipt reference',
      () async {
        final entry = await seedFile(
          workspace,
          'lib/src/usecases/get_product.dart',
          'final class GetProduct {}\n',
        );
        final receiptFile = await store.save(
          GenerationReceipt(
            schema: 'proof.v1',
            command: 'make',
            target: 'Product',
            repro: 'zfa make Product',
            at: DateTime.utc(2026, 9, 3, 10),
            generatorVersion: '6.1.0',
            input: const {},
            files: [entry],
          ),
        );

        await File(p.join(workspace.path, entry.path)).delete();

        final report = await checker.check();

        expect(report.ok, isFalse);
        final finding = report.findings.single;
        expect(finding.kind, 'deleted');
        expect(finding.path, entry.path);
        expect(finding.receipt, p.basename(receiptFile.path));
      },
    );

    test('files larger than the snapshot cap still verify by digest', () async {
      final bigBody = List.generate(6000, (i) => '// line $i').join('\n');
      final entry = await seedFile(
        workspace,
        'lib/src/di/injector.dart',
        bigBody,
        withSnapshot: false,
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'make',
          target: 'Product',
          repro: 'zfa make Product',
          at: DateTime.utc(2026, 9, 3, 10),
          generatorVersion: '6.1.0',
          input: const {},
          files: [entry],
        ),
      );

      final green = await checker.check();
      expect(green.ok, isTrue, reason: green.findings.toString());

      // Tamper: digest drift on a snapshot-less file still detected.
      await File(
        p.join(workspace.path, entry.path),
      ).writeAsString('$bigBody\n// tampered\n');
      final report = await checker.check();

      expect(report.ok, isFalse);
      final finding = report.findings.single;
      expect(finding.kind, 'modified');
      expect(
        finding.diff,
        isNull,
        reason: 'no snapshot was stored, so no line diff is possible',
      );
      expect(finding.detail, contains('digest'));
    });

    test(
      'a stale spec is detected and the receipt names the exact delta',
      () async {
        final specOriginal = 'class Product {\n  final String id;\n}\n';
        final entityEntry = await seedFile(
          workspace,
          'lib/src/domain/entities/product/product.dart',
          specOriginal,
        );
        final generatedEntry = await seedFile(
          workspace,
          'lib/src/usecases/get_product.dart',
          'final class GetProduct {}\n',
        );
        await store.save(
          GenerationReceipt(
            schema: 'proof.v1',
            command: 'make',
            target: 'Product',
            repro: 'zfa make Product',
            at: DateTime.utc(2026, 9, 3, 10),
            generatorVersion: '6.1.0',
            input: const {},
            spec: GenerationReceiptSpec(
              path: entityEntry.path,
              sha256: entityEntry.sha256,
              snapshot: specOriginal,
            ),
            files: [generatedEntry],
          ),
        );

        // The spec (entity) drifts AFTER generation: the usecase is now stale.
        await File(p.join(workspace.path, entityEntry.path)).writeAsString(
          'class Product {\n  final String id;\n  final double price;\n}\n',
        );

        final report = await checker.check();

        expect(report.ok, isFalse);
        final stale = report.findings
            .where((f) => f.kind == 'stale_spec')
            .toList(growable: false);
        expect(stale, hasLength(1));
        expect(stale.single.path, entityEntry.path);
        expect(stale.single.diff, isNotNull);
        expect(stale.single.diff!, contains('+   final double price;'));
      },
    );

    test('newest receipt wins when two receipts cover the same file', () async {
      final v1 = await seedFile(
        workspace,
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'entity create',
          target: 'Product',
          repro: 'zfa entity create Product',
          at: DateTime.utc(2026, 9, 3, 10),
          generatorVersion: '6.1.0',
          input: const {},
          files: [v1],
        ),
      );

      // Regeneration rewrites the same file and ships a newer receipt.
      final v2 = await seedFile(
        workspace,
        'lib/src/domain/entities/product/product.dart',
        'class Product {\n  final String id;\n}\n',
        action: 'modify',
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'entity add-field',
          target: 'Product',
          repro: 'zfa entity add-field Product --field id:String',
          at: DateTime.utc(2026, 9, 3, 11),
          generatorVersion: '6.1.0',
          input: const {},
          files: [v2],
        ),
      );

      final report = await checker.check();

      expect(report.ok, isTrue, reason: report.findings.toString());
      expect(
        report.filesChecked,
        1,
        reason: 'the same path covered twice counts once',
      );
    });

    test(
      '--require-coverage flags generated-code paths without receipts',
      () async {
        final entry = await seedFile(
          workspace,
          'lib/src/domain/entities/product/product.dart',
          'class Product {}\n',
        );
        await store.save(
          GenerationReceipt(
            schema: 'proof.v1',
            command: 'entity create',
            target: 'Product',
            repro: 'zfa entity create Product',
            at: DateTime.utc(2026, 9, 3, 10),
            generatorVersion: '6.1.0',
            input: const {},
            files: [entry],
          ),
        );

        // An unprovenanced artifact sits in the audited tree.
        await seedFile(
          workspace,
          'lib/src/usecases/mystery.dart',
          'final class Mystery {}\n',
          withSnapshot: false,
        );

        final report = await checker.check(coverageRoots: ['lib/src']);

        expect(report.ok, isFalse);
        final uncovered = report.findings
            .where((f) => f.kind == 'unprovenanced')
            .toList(growable: false);
        expect(uncovered, hasLength(1));
        expect(uncovered.single.path, 'lib/src/usecases/mystery.dart');
      },
    );

    test('coverage roots ignore .zfa, .git and .dart_tool trees', () async {
      final entry = await seedFile(
        workspace,
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'entity create',
          target: 'Product',
          repro: 'zfa entity create Product',
          at: DateTime.utc(2026, 9, 3, 10),
          generatorVersion: '6.1.0',
          input: const {},
          files: [entry],
        ),
      );

      for (final junk in [
        '.zfa/receipts/state.json',
        '.git/internal/config.json',
        '.dart_tool/package_config.json',
      ]) {
        await seedFile(workspace, junk, '{}', withSnapshot: false);
      }

      final report = await checker.check(coverageRoots: ['.']);

      expect(report.ok, isTrue, reason: report.findings.toString());
    });

    test('report JSON carries the proof.v1 machine envelope', () async {
      final entry = await seedFile(
        workspace,
        'lib/src/domain/entities/product/product.dart',
        'class Product {}\n',
      );
      await store.save(
        GenerationReceipt(
          schema: 'proof.v1',
          command: 'entity create',
          target: 'Product',
          repro: 'zfa entity create Product',
          at: DateTime.utc(2026, 9, 3, 10),
          generatorVersion: '6.1.0',
          input: const {},
          files: [entry],
        ),
      );

      final report = await checker.check();
      final json = report.toJson();

      expect(json['schema'], 'proof.v1');
      expect(json['ok'], isTrue);
      expect(json['receipts'], 1);
      expect(json['filesChecked'], 1);
      expect(json['findings'], isEmpty);
    });
  });
}
