// RED tests for spec 1193 B-007 — the realization receipt: the
// machine-readable record of the MOCKED→REAL swap (files, digests, gate
// outcome, ladder, generated/mock/hand ratios), double-shaped so
// `zfa proof check` parses and counts it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/realize_receipt.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt_test_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('fileFor: one stable file per (feature, adapter) pair', () {
    final writer = RealizeReceiptWriter(projectRoot: root.path);
    final file = writer.fileFor('090-tdd-fixture', 'firestore');
    expect(
      p.relative(file.path, from: root.path),
      '.zfa/receipts/realize.090-tdd-fixture.firestore.receipt.json',
    );
  });

  test('documentFor: the swap record carries files, digests, gates, '
      'ladder, and ratios inside a proof.v1 envelope', () {
    final bytes = utf8.encode('final binding bytes');
    final digest = crypto.sha256.convert(bytes).toString();
    final doc = RealizeReceiptWriter.documentFor(
      feature: '090-tdd-fixture',
      adapterName: 'firestore',
      entities: [
        EntitySwap(
          entity: 'User',
          mockClass: 'UserMockDataSource',
          adapterClass: 'UserFirestoreAdapter',
          adapterFile:
              'lib/src/data/datasources/user/'
              'user_firestore_adapter.dart',
          scaffolded: true,
          bindingSites: 2,
          interfaceFilesUntouched: 3,
        ),
      ],
      contractVerdict: 'green',
      differentialVerdict: 'pass',
      drift: '0.0',
      threshold: '0.0',
      fixturesRun: 1,
      ladder: const {
        'B-001': ['MOCKED', 'REAL', 'DONE'],
      },
      ratios: const {
        'generated': 3,
        'mock': 1,
        'hand': 2,
        'handDelta': 1,
        'handWritten': 1,
        'total': 7,
      },
      simulationBinding: const {
        'retired': true,
        'manifest': 'specs/090-tdd-fixture/tdd/fixtures/manifest.json',
        'digest': 'deadbeef',
      },
      suitePaths: const ['test/b001_test.dart'],
      handDeltas: 1,
      files: [
        GenerationReceiptFile(
          path: 'lib/src/di/datasources/user_mock_datasource_di.dart',
          action: 'update',
          sha256: digest,
          bytes: bytes.length,
        ),
        GenerationReceiptFile(
          path: 'specs/090-tdd-fixture/tdd/fixtures/manifest.json',
          action: 'delete',
          sha256: 'cafe',
          bytes: 12,
        ),
      ],
    );

    // The proof.v1 envelope — what ReceiptStore/proof check parse.
    expect(doc['schema'], 'proof.v1');
    expect(doc['command'], 'zfa tdd realize');
    expect(doc['target'], '090-tdd-fixture');
    expect(doc['repro'], 'zfa tdd realize 090-tdd-fixture --adapter firestore');
    expect(doc['input'], isA<Map>());
    expect(doc['input']['feature'], '090-tdd-fixture');
    expect(doc['input']['adapter'], 'firestore');

    // The realization payload.
    expect(doc['realize_schema'], 'realize.v1');
    expect(doc['gates'], isA<Map>());
    expect(doc['gates']['contract'], 'green');
    expect(doc['gates']['differential'], isA<Map>());
    expect(doc['gates']['differential']['verdict'], 'pass');
    expect(doc['gates']['differential']['drift'], '0.0');
    expect(doc['gates']['differential']['fixtures'], 1);
    expect(doc['ladder'], isA<Map>());
    expect((doc['ladder'] as Map)['B-001'], ['MOCKED', 'REAL', 'DONE']);
    expect(doc['ratios'], isA<Map>());
    expect(doc['ratios']['generated'], 3);
    expect(doc['ratios']['mock'], 1);
    expect(doc['ratios']['hand'], 2);
    expect(doc['simulation_binding'], isA<Map>());
    expect((doc['simulation_binding'] as Map)['retired'], isTrue);
    expect(doc['entities'], isA<List>());
    expect((doc['entities'] as List).first, isA<Map>());

    // Files carry the digests the checker re-derives.
    final files = doc['files'] as List;
    expect(files, hasLength(2));
    expect((files.first as Map)['sha256'], digest);
    expect((files.last as Map)['action'], 'delete');

    // The envelope parses as a GenerationReceipt (zfa proof check).
    final receipt = GenerationReceipt.fromJson(Map<String, dynamic>.from(doc));
    expect(receipt.command, 'zfa tdd realize');
    expect(receipt.files, hasLength(2));
    expect(receipt.files.first.sha256, digest);
  });

  test('write() lands the receipt on disk, indented + parseable', () async {
    final writer = RealizeReceiptWriter(projectRoot: root.path);
    final file = await writer.write(
      feature: '090-tdd-fixture',
      adapterName: 'firestore',
      entities: const [],
      contractVerdict: 'green',
      differentialVerdict: 'skipped',
      drift: '-',
      threshold: '0.0',
      fixturesRun: 0,
      ladder: const {},
      ratios: const {},
      simulationBinding: const {'retired': false},
      suitePaths: const [],
      handDeltas: 0,
      files: const [],
    );

    expect(await file.exists(), isTrue);
    final doc = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(doc['schema'], 'proof.v1');
    expect(doc['command'], 'zfa tdd realize');
  });
}
