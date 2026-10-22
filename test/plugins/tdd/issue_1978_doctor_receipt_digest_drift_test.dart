// Issue #1978 — `zfa tdd doctor` must see the receipt-digest drift that
// `zfa tdd verify`'s receipt preflight refuses the feature for.
//
// Reported state (arrrrny/zuraffa#1978):
//
//   $ zfa tdd doctor 002-subscription-error-vocabulary --repair
//   zfa tdd doctor: feature 002-subscription-error-vocabulary
//     stores agree — no drift detected
//   {"command":"doctor","verdict":"healthy","prescription":"none","drifts":[]}
//
//   $ zfa tdd verify --feature 002-subscription-error-vocabulary
//   zfa tdd verify: receipt preflight — FAIL
//      receipts checked: 386, findings: 74
//      [modified] test/tdd/001-purchase-store/u1_test.dart — digest
//      mismatch: receipt says 3989017dae5c, disk has fbf3fab4334b
//      (action: update); reproduce with: zfa tdd verify-red U1 --re-certify
//
// The two commands disagree about the SAME state: the preflight re-derives
// every receipted artifact's digest against the bytes on disk, the doctor's
// store-vs-store comparisons never did, so a feature whose receipts drifted
// read "healthy" while the release gate refused it.
//
// Contract under test:
//   E1  the drifted receipted artifact is reported by `zfa tdd doctor` —
//       never "stores agree" — and the drift line names the file and the
//       per-file prescription the receipt names
//       (`verify-red --re-certify` / `make --born-green`);
//   E2  the doctor's finding is the SAME check the receipt preflight runs
//       (`ReceiptPreflight` -> `ProofChecker`), so doctor and verify can no
//       longer disagree about one state;
//   E3  the destructive generator re-drive (`zfa tdd gen`, issue #1375) is
//       never prescribed — the sanctioned re-certification transition is;
//   E4  a receipt whose recorded digest still matches the bytes on disk
//       leaves the feature healthy (no false drift).
//   E5  the SUBJECT side of a drifted behavior is re-bound with the
//       born-green transition (`make --born-green`), the TEST side with the
//       red re-certification (`verify-red --re-certify`) — a generator
//       receipt owns both sides of a behavior.
//
// Fast tier: in-process fixture + `CliRunner` (no subprocesses).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/core/project/test_receipt.dart';
import 'package:zuraffa/src/plugins/tdd/services/receipt_preflight.dart';

void main() {
  late Directory root;

  /// The queried feature (the doctor target) — healthy on its own.
  const queriedFeature = '002-subscription-error-vocabulary';

  /// The feature whose receipted lane artifact drifted — the shape the
  /// issue reports: the drift belongs to another feature's generated lane,
  /// yet it blocks the queried feature's `zfa tdd verify`.
  const driftedFeature = '001-purchase-store';

  /// The drifted artifact (a generated lane of the other feature).
  const driftedRelPath = 'test/tdd/$driftedFeature/u1_test.dart';

  /// The bytes the receipt recorded at certification time.
  const certifiedBytes = '// U1 — certified bytes\n';

  /// The bytes on disk now (the release reformatted them).
  const currentBytes = '// U1 — reformatted by the release\n';

  /// Seed the queried feature: a registry whose recorded test/subject both
  /// exist on disk (so no OTHER doctor check fires) and carry no imports
  /// (so the import-resolution checks stay silent).
  Future<void> seedQueriedFeature() async {
    final tddDir = Directory(p.join(root.path, 'specs', queriedFeature, 'tdd'));
    await tddDir.create(recursive: true);
    for (final rel in [
      'test/tdd/$queriedFeature/u1_test.dart',
      'lib/tdd/$queriedFeature/u1_subject.dart',
    ]) {
      final file = File(p.join(root.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('// $rel\n');
    }
    await File(p.join(tddDir.path, 'artifacts.json')).writeAsString(
      jsonEncode({
        'feature': queriedFeature,
        'records': [
          {
            'behavior_id': 'U1',
            'feature': queriedFeature,
            'source_criterion': 'FR-001',
            'test_path': 'test/tdd/$queriedFeature/u1_test.dart',
            'subject_path': 'lib/tdd/$queriedFeature/u1_subject.dart',
            'runnable_test_name':
                'test/tdd/$queriedFeature/u1_test.dart::U1::the query works',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-10-01T00:00:00.000Z',
          },
        ],
      }),
    );
  }

  /// The drifted artifact on disk.
  Future<void> seedDriftedArtifact() async {
    final file = File(p.join(root.path, driftedRelPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(currentBytes);
  }

  /// Seed the receipt that covers the drifted artifact. [repro] is the
  /// receipt's own reproduction command — the per-file prescription the
  /// preflight prints.
  Future<void> seedReceipt({required String repro, String? behavior}) async {
    final certified = crypto.sha256
        .convert(utf8.encode(certifiedBytes))
        .toString();
    await ReceiptStore(projectRoot: root.path).save(
      GenerationReceipt(
        command: 'tdd verify-red $behavior --re-certify',
        target: behavior ?? 'U1',
        repro: repro,
        at: DateTime.utc(2026, 10, 2),
        generatorVersion: '7.2.0',
        input: {
          'feature': driftedFeature,
          'behavior': behavior ?? 'U1',
          'sanctioned': true,
          'hand_delta': true,
          'transition': 're-certify',
        },
        files: [
          GenerationReceiptFile(
            path: driftedRelPath,
            action: 'update',
            sha256: certified,
            bytes: certifiedBytes.length,
          ),
        ],
      ),
    );
  }

  /// A proof.v1 receipt that does NOT drift. Its presence activates the
  /// receipt preflight's gate — the doctor's check is vacuous without a
  /// proof.v1 receipt, exactly like the verify gate.
  Future<void> seedHealthyReceipt() async {
    const rel = 'lib/tdd/$queriedFeature/u1_subject.dart';
    final bytes = '// $rel\n';
    await ReceiptStore(projectRoot: root.path).save(
      GenerationReceipt(
        command: 'tdd make U1 --born-green',
        target: 'U1',
        repro: 'zfa tdd make U1 --born-green',
        at: DateTime.utc(2026, 10, 2),
        generatorVersion: '7.2.0',
        input: {'feature': queriedFeature, 'behavior': 'U1'},
        files: [
          GenerationReceiptFile(
            path: rel,
            action: 'update',
            sha256: crypto.sha256.convert(utf8.encode(bytes)).toString(),
            bytes: bytes.length,
          ),
        ],
      ),
    );
  }

  /// The doctor verdict — the last non-empty stdout line (bug #840).
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  List<String> doctorArgs() => [
    'tdd',
    'doctor',
    queriedFeature,
    '--project',
    root.path,
  ];

  setUp(() {
    root = Directory.systemTemp.createTempSync('issue_1978_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    exitCode = 0;
  });

  group('issue #1978 — doctor sees the receipt-digest drift', () {
    test('E1: a drifted receipted artifact is reported as a drift with the '
        'per-file prescription — never "stores agree"', () async {
      await seedQueriedFeature();
      await seedDriftedArtifact();
      await seedReceipt(repro: 'zfa tdd verify-red U1 --re-certify');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(
        CliRunner.lastDispatchedExitCode,
        isNot(0),
        reason: 'a drifted receipt must not read healthy:\n$out',
      );
      expect(
        out,
        isNot(contains('stores agree')),
        reason:
            'the doctor must not claim the stores agree while a receipted '
            'artifact drifted (issue #1978):\n$out',
      );
      expect(
        out,
        contains(driftedRelPath),
        reason: 'the drift line must name the drifted file:\n$out',
      );
      expect(
        out,
        contains('zfa tdd verify-red U1 --re-certify'),
        reason:
            'the per-file prescription is the receipt\'s own reproduction '
            'command (the transition that re-binds the evidence to the '
            'current bytes):\n$out',
      );

      final v = verdict(out);
      expect(v['verdict'], 'drift', reason: out);
      expect(v['prescription'], 're-certify', reason: out);
      expect(
        v['fix'],
        contains('zfa tdd verify-red U1 --re-certify'),
        reason: out,
      );
      expect(
        (v['drifts'] as List).join('\n'),
        contains(driftedRelPath),
        reason: 'the machine-readable verdict must carry the drift:\n$out',
      );
    });

    test(
      'E2: the doctor finding IS the check the receipt preflight runs',
      () async {
        await seedQueriedFeature();
        await seedDriftedArtifact();
        await seedReceipt(repro: 'zfa tdd verify-red U1 --re-certify');

        // The preflight `zfa tdd verify` runs before its audit.
        final preflight = await ReceiptPreflight(
          projectRoot: root.path,
        ).check();
        expect(
          preflight.ok,
          isFalse,
          reason: 'the preflight must refuse the drifted receipt',
        );
        expect(
          preflight.findings.map((f) => f.kind),
          contains('modified'),
          reason: 'the drift class is a digest mismatch:\n$preflight',
        );
        expect(
          preflight.findings.map((f) => f.path),
          contains(driftedRelPath),
          reason: 'the preflight names the drifted file',
        );

        // The doctor must report the SAME file — the two commands may not
        // disagree about one state (issue #1978).
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(doctorArgs());
        expect(out, contains(driftedRelPath), reason: out);
      },
    );

    test('E3: the destructive generator re-drive is never prescribed '
        '(issue #1375) — the sanctioned re-certification is', () async {
      await seedQueriedFeature();
      await seedDriftedArtifact();
      // The drifted artifact's LATEST receipt is the gen receipt — its
      // repro would re-drive the generator over the certified work.
      await seedReceipt(repro: 'zfa tdd gen U1');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(
        CliRunner.lastDispatchedExitCode,
        isNot(0),
        reason: 'the drift must still be reported:\n$out',
      );
      expect(
        out,
        contains(driftedRelPath),
        reason: 'the drift line must name the drifted file:\n$out',
      );
      expect(
        out,
        isNot(contains('zfa tdd gen')),
        reason:
            're-driving the generator destroys the certified work '
            '(issue #1375) — the prescription must be the re-certify '
            'transition:\n$out',
      );
      expect(
        out,
        contains('zfa tdd verify-red U1 --re-certify'),
        reason: 'the sanctioned transition must be named:\n$out',
      );
    });

    test('E4: a receipt whose digest still matches the bytes on disk leaves '
        'the feature healthy', () async {
      await seedQueriedFeature();
      await seedDriftedArtifact();
      // The receipt records the CURRENT bytes — nothing drifted.
      final current = crypto.sha256
          .convert(utf8.encode(currentBytes))
          .toString();
      await ReceiptStore(projectRoot: root.path).save(
        GenerationReceipt(
          command: 'tdd verify-red U1 --re-certify',
          target: 'U1',
          repro: 'zfa tdd verify-red U1 --re-certify',
          at: DateTime.utc(2026, 10, 2),
          generatorVersion: '7.2.0',
          input: {
            'feature': driftedFeature,
            'behavior': 'U1',
            'sanctioned': true,
            'hand_delta': true,
            'transition': 're-certify',
          },
          files: [
            GenerationReceiptFile(
              path: driftedRelPath,
              action: 'update',
              sha256: current,
              bytes: currentBytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
      expect(out, contains('stores agree'), reason: out);
      expect(verdict(out)['verdict'], 'healthy', reason: out);
    });

    test('E5: the drifted SUBJECT of a generator receipt is re-bound with the '
        'born-green transition — not the test re-certification', () async {
      await seedQueriedFeature();
      // The drifted artifact is the SUBJECT side of a generated behavior —
      // a generator receipt owns the test AND the subject.
      const subjectRelPath = 'lib/tdd/$driftedFeature/u1_subject.dart';
      final subject = File(p.join(root.path, subjectRelPath));
      await subject.parent.create(recursive: true);
      await subject.writeAsString(currentBytes);
      final certified = crypto.sha256
          .convert(utf8.encode(certifiedBytes))
          .toString();
      await ReceiptStore(projectRoot: root.path).save(
        GenerationReceipt(
          command: 'tdd gen',
          target: 'U1',
          repro: 'zfa tdd gen',
          at: DateTime.utc(2026, 10, 2),
          generatorVersion: '7.2.0',
          input: {'feature': driftedFeature},
          files: [
            GenerationReceiptFile(
              path: subjectRelPath,
              action: 'create',
              sha256: certified,
              bytes: certifiedBytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      expect(out, contains(subjectRelPath), reason: out);
      expect(
        out,
        isNot(contains('zfa tdd gen')),
        reason:
            're-driving the generator destroys the certified work '
            '(issue #1375):\n$out',
      );
      expect(
        out,
        contains('zfa tdd make U1 --born-green'),
        reason:
            'the subject side is re-bound with the born-green transition:\n$out',
      );
    });

    test('E6: a drifted test.v1 receipt is reported with the digests the '
        'receipt DOES carry and its own regenerate command', () async {
      await seedQueriedFeature();
      await seedHealthyReceipt();

      // The test plugin's receipt family (`test-*.json`, schema test.v1) —
      // a SEPARATE document kind `ReceiptStore.loadAll` skips. The shared
      // checker audits it, so the doctor must resolve it too: a drift
      // line that says `receipt says unknown` states a digest the
      // receipt does not have.
      const testRelPath = 'test/unit/purchase_test.dart';
      final testFile = File(p.join(root.path, testRelPath));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(currentBytes);
      final certified = crypto.sha256
          .convert(utf8.encode(certifiedBytes))
          .toString();
      await TestReceiptStore(projectRoot: root.path).write(
        TestReceipt(
          entity: 'Purchase',
          command: 'zfa test create --name Purchase',
          at: DateTime.utc(2026, 10, 2),
          tests: [
            TestReceiptEntry(
              name: 'the query works',
              testPath: testRelPath,
              method: 'get',
              acceptancePath: 'success',
              testSha256: certified,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      expect(out, contains(testRelPath), reason: out);
      expect(
        out,
        isNot(contains('receipt says unknown')),
        reason:
            'the test.v1 receipt DOES carry the digest — the doctor must '
            'not state one it does not have:\n$out',
      );
      expect(
        out,
        contains(certified.substring(0, 12)),
        reason: 'the recorded digest must be the receipt\'s own:\n$out',
      );
      expect(
        out,
        contains('zfa test create --name Purchase'),
        reason:
            'the receipt\'s own regenerate command is the prescription — '
            'the doctor must not fall back to an unrelated command:\n$out',
      );
    });

    test('E7: a receipted artifact that is GONE is reported — the doctor '
        'may not disagree with the verify gate about a deleted artifact',
        () async {
      await seedQueriedFeature();
      // The receipt names an artifact that no longer exists on disk.
      const goneRelPath = 'lib/tdd/$driftedFeature/gone_subject.dart';
      final certified = crypto.sha256
          .convert(utf8.encode(certifiedBytes))
          .toString();
      await ReceiptStore(projectRoot: root.path).save(
        GenerationReceipt(
          command: 'tdd verify-red U1 --re-certify',
          target: 'U1',
          repro: 'zfa tdd verify-red U1 --re-certify',
          at: DateTime.utc(2026, 10, 2),
          generatorVersion: '7.2.0',
          input: {'feature': driftedFeature, 'behavior': 'U1'},
          files: [
            GenerationReceiptFile(
              path: goneRelPath,
              action: 'create',
              sha256: certified,
              bytes: certifiedBytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      expect(out, contains(goneRelPath), reason: out);
      expect(
        out,
        contains('missing'),
        reason:
            'a receipted artifact that is gone is the same receipt-vs-disk '
            'class the verify gate refuses the feature for:\n$out',
      );
      expect(
        out,
        isNot(contains('stores agree')),
        reason: out,
      );
    });

    test('E8: a generator receipt never prescribes its own id-less repro — '
        'the id-bearing re-certification transition is named', () async {
      await seedQueriedFeature();
      // The `tdd compose` verb stamps an id-less repro ('zfa tdd
      // compose') — a hint that cannot be pasted as-is.
      const subjectRelPath = 'lib/tdd/$driftedFeature/u1_subject.dart';
      final subject = File(p.join(root.path, subjectRelPath));
      await subject.parent.create(recursive: true);
      await subject.writeAsString(currentBytes);
      final certified = crypto.sha256
          .convert(utf8.encode(certifiedBytes))
          .toString();
      await ReceiptStore(projectRoot: root.path).save(
        GenerationReceipt(
          command: 'tdd compose',
          target: 'U1',
          repro: 'zfa tdd compose',
          at: DateTime.utc(2026, 10, 2),
          generatorVersion: '7.2.0',
          input: {'feature': driftedFeature},
          files: [
            GenerationReceiptFile(
              path: subjectRelPath,
              action: 'update',
              sha256: certified,
              bytes: certifiedBytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      expect(out, contains(subjectRelPath), reason: out);
      expect(
        out,
        isNot(contains('zfa tdd compose')),
        reason:
            'the id-less repro cannot be pasted as-is, and re-driving a '
            'generator over certified work destroys it (issue #1375):\n$out',
      );
      expect(
        out,
        contains('zfa tdd make U1 --born-green'),
        reason:
            'the subject side is re-bound with the born-green transition, '
            'which carries the behavior id:\n$out',
      );
    });

    test('E9: the drift line carries the digests the checker derived — the '
        'recorded one and the one on disk', () async {
      await seedQueriedFeature();
      await seedDriftedArtifact();
      await seedReceipt(repro: 'zfa tdd verify-red U1 --re-certify');

      final certified = crypto.sha256
          .convert(utf8.encode(certifiedBytes))
          .toString();
      final current = crypto.sha256.convert(utf8.encode(currentBytes)).toString();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      expect(
        out,
        contains(certified.substring(0, 12)),
        reason: 'the receipt\'s recorded digest must be reported:\n$out',
      );
      expect(
        out,
        contains(current.substring(0, 12)),
        reason: 'the digest on disk must be reported:\n$out',
      );
    });
  });
}
