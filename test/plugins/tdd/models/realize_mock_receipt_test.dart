import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/realize_mock_receipt.dart';

/// Spec 1009 (issue #1009) — the differential receipt model: per-method
/// `{method, tier1_result, tier2_result, diff}`, the per-entity gate
/// verdict, and the round-trip through disk.
void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_rm_receipt_');
    projectRoot = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RealizeMockReceipt receipt(List<List<bool>> outcomes) => RealizeMockReceipt(
    entity: 'Login',
    interfaceName: 'LoginDataSource',
    against: 'firestore',
    contractTestPath: 'test/mock/login/login_mock_contract_test.dart',
    contractDigest: 'abc',
    tier2Subject: 'LoginTier2MockProvider',
    tier2TestDigest: 'def',
    methods: [
      for (var i = 0; i < outcomes.length; i++)
        RealizeMockMethodResult(
          method: ['get', 'update', 'toggle'][i],
          tier1Passed: outcomes[i][0],
          tier2Passed: outcomes[i][1],
        ),
    ],
    sandbox: const {},
  );

  group('per-method rows', () {
    test('both pass → diff none', () {
      const row = RealizeMockMethodResult(
        method: 'get',
        tier1Passed: true,
        tier2Passed: true,
      );
      expect(row.tier1Result, 'pass');
      expect(row.tier2Result, 'pass');
      expect(row.diff, 'none');
      expect(row.toJson(), {
        'method': 'get',
        'tier1_result': 'pass',
        'tier2_result': 'pass',
        'diff': 'none',
      });
    });

    test('tier2 fails while tier1 passes → diff mismatch', () {
      const row = RealizeMockMethodResult(
        method: 'get',
        tier1Passed: true,
        tier2Passed: false,
      );
      expect(row.diff, 'mismatch');
      expect(row.toJson()['diff'], 'mismatch');
    });

    test('both fail → diff none (the divergence is the disagreement)', () {
      const row = RealizeMockMethodResult(
        method: 'get',
        tier1Passed: false,
        tier2Passed: false,
      );
      expect(row.diff, 'none');
    });
  });

  group('gate verdicts (per-entity, attribution-honest)', () {
    test('all green both tiers → certified', () {
      final r = receipt([
        [true, true],
        [true, true],
        [true, true],
      ]);
      expect(r.gate, RealizeMockGate.certified);
      expect(r.divergences, isEmpty);
      expect(r.tier1Failures, isEmpty);
      expect(r.toJson()['result'], 'certified');
    });

    test('a divergent method → mismatch + named', () {
      final r = receipt([
        [true, false],
        [true, true],
        [true, true],
      ]);
      expect(r.gate, RealizeMockGate.mismatch);
      expect(r.divergences, ['get']);
    });

    test('green tier1, red tier2 everywhere → mismatch on every method', () {
      final r = receipt([
        [true, false],
        [true, false],
        [true, false],
      ]);
      expect(r.divergences, ['get', 'update', 'toggle']);
    });

    test('red tier1 with no divergence → tier1-red (never certified)', () {
      // A broken baseline cannot certify anything — the gate refuses
      // instead of dressing a red-red pair up as "certified".
      final r = receipt([
        [false, false],
        [true, true],
        [true, true],
      ]);
      expect(r.gate, RealizeMockGate.tier1Red);
      expect(r.tier1Failures, ['get']);
      expect(r.divergences, isEmpty);
    });

    test('red tier1 + green tier2 IS a divergence (mismatch wins)', () {
      final r = receipt([
        [false, true],
        [true, true],
      ]);
      expect(r.gate, RealizeMockGate.mismatch);
    });
  });

  group('disk round-trip', () {
    test('toJson → fromJson preserves every row and the verdict', () async {
      final r = receipt([
        [true, true],
        [true, false],
        [false, false],
      ]);
      final file = File(
        p.join(projectRoot, realizeMockReceiptPath('Login', 'firestore')),
      );
      const encoder = JsonEncoder.withIndent('  ');
      await file.parent.create(recursive: true);
      await file.writeAsString('${encoder.convert(r.toJson())}\n');

      final loaded = loadRealizeMockReceipt(projectRoot, 'Login', 'firestore');
      expect(loaded, isNotNull);
      expect(loaded!.entity, 'Login');
      expect(loaded.against, 'firestore');
      expect(loaded.methods, hasLength(3));
      expect(loaded.methods[1].diff, 'mismatch');
      expect(loaded.gate, RealizeMockGate.mismatch);
      expect(loaded.divergences, ['update']);
      expect(loaded.contractDigest, 'abc');
    });

    test('missing or corrupt receipts are null, never a guess', () async {
      expect(
        loadRealizeMockReceipt(projectRoot, 'Login', 'firestore'),
        isNull,
        reason: 'absent receipt → null',
      );

      final file = File(
        p.join(projectRoot, realizeMockReceiptPath('Login', 'firestore')),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('not json at all');
      expect(
        loadRealizeMockReceipt(projectRoot, 'Login', 'firestore'),
        isNull,
        reason: 'corrupt receipt → null',
      );
    });

    test('the canonical path names entity + backend', () {
      expect(
        realizeMockReceiptPath('Login', 'firestore'),
        p.join('test', 'mock', 'login', 'realize.Login.firestore.receipt.json'),
      );
    });
  });

  test('digestOf hashes the source bytes (sha-256)', () {
    expect(
      RealizeMockReceipt.digestOf('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
