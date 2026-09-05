/// Spec 968 — world run receipts (U9; #807 composes): every green run
/// is attributable to a world version.
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/simulation/worlds/world_run_receipt.dart';

void main() {
  late io.Directory project;

  setUp(() async {
    project = await io.Directory.systemTemp.createTemp('world-receipt');
  });

  tearDown(() async {
    await project.delete(recursive: true);
  });

  WorldRunReceipt _green(String worldHash) => WorldRunReceipt(
    scenario: 'checkout-flow',
    feature: 'spec-968',
    worldHash: worldHash,
    seed: 968,
    verdict: 'GREEN',
    passed: true,
    worldValid: true,
    plays: 7,
    runDigest: 'digest-$worldHash',
    virtualElapsedMs: 431,
    at: '2026-09-05T00:00:00.000Z',
    path: '',
  );

  test(
    'save + load round-trips through .zfa/receipts/ (proof.v1-parseable)',
    () async {
      final store = WorldRunReceiptStore(projectRoot: project.path);
      await store.save(_green('hash-aaa'));

      final receiptFile = io.File(
        p.join(
          project.path,
          '.zfa',
          'receipts',
          'world-run-checkout-flow.json',
        ),
      );
      expect(
        receiptFile.existsSync(),
        isTrue,
        reason: 'the deterministic receipt name is addressable',
      );

      // The document stays a parseable proof.v1 generation receipt (the
      // saveNamed contract — zfa proof check keeps seeing it) with the
      // world extras merged on top.
      final doc =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
      expect(doc['schema'], 'proof.v1');
      expect(doc['command'], 'simulate run checkout-flow');
      expect(doc['plugin'], 'simulate');
      expect(
        doc['repro'],
        'zfa simulate run checkout-flow --feature spec-968 --seed 968',
      );
      expect(doc['world_hash'], 'hash-aaa');
      expect(doc['verdict'], 'GREEN');
      expect(doc['run_digest'], 'digest-hash-aaa');

      final loaded = store.load('checkout-flow');
      expect(loaded!.worldHash, 'hash-aaa');
      expect(loaded.passed, isTrue);
      expect(loaded.worldValid, isTrue);
      expect(loaded.runDigest, 'digest-hash-aaa');
      expect(loaded.seed, 968);
      expect(loaded.plays, 7);
      expect(loaded.virtualElapsedMs, 431);
    },
  );

  test(
    'a save supersedes the previous receipt in place (latest wins)',
    () async {
      final store = WorldRunReceiptStore(projectRoot: project.path);
      await store.save(_green('hash-aaa'));
      await store.save(
        WorldRunReceipt(
          scenario: 'checkout-flow',
          feature: 'spec-968',
          worldHash: 'hash-bbb',
          seed: 968,
          verdict: 'RED',
          passed: false,
          worldValid: false,
          plays: 0,
          runDigest: '',
          virtualElapsedMs: 0,
          at: '2026-09-05T00:01:00.000Z',
          path: '',
          invalidatedBy: 'world-mutation',
        ),
      );

      final loaded = store.load('checkout-flow');
      expect(loaded!.worldHash, 'hash-bbb');
      expect(loaded.worldValid, isFalse);
      expect(loaded.passed, isFalse);
      expect(loaded.invalidatedBy, 'world-mutation');
    },
  );

  test('no receipt and corrupt receipts are honestly absent/null', () async {
    final store = WorldRunReceiptStore(projectRoot: project.path);
    expect(store.load('checkout-flow'), isNull);

    final receipts = io.Directory(p.join(project.path, '.zfa', 'receipts'))
      ..createSync(recursive: true);
    io.File(
      p.join(receipts.path, 'world-run-broken.json'),
    ).writeAsStringSync('{broken');
    expect(store.load('broken'), isNull);
  });

  test('the receipt name is sanitized (bare name inside receipts/)', () async {
    final store = WorldRunReceiptStore(projectRoot: project.path);
    expect(store.fileNameFor('checkout-flow'), 'world-run-checkout-flow.json');
    expect(store.fileNameFor('weird/name'), 'world-run-weird_name.json');
  });

  test(
    'the proof.v1 receipt verifies through the shared ReceiptStore',
    () async {
      final store = WorldRunReceiptStore(projectRoot: project.path);
      final file = await store.save(_green('hash-ccc'));

      // The shared loader (zfa proof check's reader) parses it.
      final records = await ReceiptStore(projectRoot: project.path).loadAll();
      expect(records, hasLength(1));
      expect(records.single.receipt.command, 'simulate run checkout-flow');
      expect(records.single.receipt.plugin, 'simulate');
      expect(p.basename(file.path), 'world-run-checkout-flow.json');
    },
  );
}
