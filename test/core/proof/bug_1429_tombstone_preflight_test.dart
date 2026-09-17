// Bug #1429 — the proof preflight must treat a receipted REMOVAL as
// provenance, not drift.
//
// RED evidence: `ProofChecker` unconditionally emitted a `deleted` finding
// for every receipted path missing on disk. After the issue's hand-deletion
// of a mis-declared entity, the surviving `entity_create` receipt made that
// finding permanent — `zfa proof check` red forever and `zfa tdd verify`
// blocked by the receipt preflight gate, with no CLI path back.
//
// The fix: the tombstone receipt `zfa entity remove` writes records the
// deletion intent with `action: 'delete'`; when the LATEST receipt entry
// covering a missing path is a deletion, the absence is provenance.
//
// Unit tier: a seeded `.zfa/receipts/` store + ProofChecker/ReceiptPreflight
// against a throwaway workspace — no subprocesses.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/receipt_preflight.dart';

void main() {
  late Directory workspace;
  late ReceiptStore store;
  const entityPath = 'lib/src/domain/entities/product/product.dart';

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('bug_1429_proof_');
    store = ReceiptStore(projectRoot: workspace.path);
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

  Future<void> seedCreateReceipt() async {
    final file = File(p.join(workspace.path, entityPath));
    await file.create(recursive: true);
    await file.writeAsString('// entity Product\n');
    await store.save(
      GenerationReceipt(
        command: 'entity create',
        target: 'Product',
        repro: 'zfa entity create -n Product',
        at: DateTime.now().toUtc(),
        generatorVersion: 'test',
        input: const <String, dynamic>{},
        files: [
          GenerationReceiptFile(
            path: entityPath,
            action: 'create',
            sha256: 'deadbeefproduct',
            bytes: 0,
          ),
        ],
        plugin: 'entity',
        capability: 'create',
        entity: 'Product',
        methodset: const <String>[],
        receiptVersion: 1,
      ),
    );
  }

  Future<void> seedTombstoneReceipt() async {
    await store.saveNamed(
      'entity-remove-product.json',
      GenerationReceipt(
        command: 'entity remove',
        target: 'Product',
        repro: 'zfa entity remove -n Product',
        at: DateTime.now().toUtc(),
        generatorVersion: 'test',
        input: const <String, dynamic>{'removed': true},
        files: [
          GenerationReceiptFile(
            path: entityPath,
            action: 'delete',
            sha256: 'deadbeefproduct',
            bytes: 0,
          ),
        ],
        plugin: 'entity',
        capability: 'remove',
        entity: 'Product',
        methodset: const <String>[],
        receiptVersion: 1,
      ),
    );
  }

  group('bug 1429 — tombstone-aware proof preflight', () {
    test('C1: the hand-deleted state reports deleted (baseline poisoning); '
        'after the tombstone the same store checks green — via ProofChecker '
        'AND ReceiptPreflight', () async {
      await seedCreateReceipt();
      // Hand-delete the scaffold: the pre-#1429 poisoned state.
      File(p.join(workspace.path, entityPath)).deleteSync();

      final poisoned = await ProofChecker(projectRoot: workspace.path).check();
      expect(poisoned.ok, isFalse, reason: 'the baseline must stay honest');
      expect(
        poisoned.findings
            .where((f) => f.kind == ProofFinding.kindDeleted)
            .map((f) => f.path),
        contains(entityPath),
      );

      // The receipted removal: the tombstone suppresses the finding.
      await seedTombstoneReceipt();

      final healed = await ProofChecker(projectRoot: workspace.path).check();
      expect(
        healed.ok,
        isTrue,
        reason: healed.findings.map((f) => f.detail).join('\n'),
      );

      // The tdd-verify preflight gate inherits the tolerance (it folds
      // ProofChecker findings 1:1).
      final gate = await ReceiptPreflight(projectRoot: workspace.path).check();
      expect(
        gate.ok,
        isTrue,
        reason: gate.findings.map((f) => f.toString()).join('\n'),
      );
    });

    test('C2: a live tombstone does not hide a recreated file — different '
        'bytes after a delete receipt still flag modified drift', () async {
      await seedCreateReceipt();
      await seedTombstoneReceipt();
      // Recreated AFTER the removal with different bytes: the latest
      // (tombstone) entry no longer matches the disk — drift, honestly.
      final recreated = File(p.join(workspace.path, entityPath));
      await recreated.create(recursive: true);
      await recreated.writeAsString('// entity Product v2\n');

      final report = await ProofChecker(projectRoot: workspace.path).check();
      expect(
        report.ok,
        isFalse,
        reason: 'a recreated artifact must not silently pass',
      );
      expect(
        report.findings
            .where((f) => f.kind == ProofFinding.kindDeleted)
            .toList(),
        isEmpty,
        reason: 'the absence was receipted — never a deleted finding',
      );
      expect(
        report.findings
            .where((f) => f.kind == ProofFinding.kindModified)
            .map((f) => f.path),
        contains(entityPath),
      );
    });
  });
}
