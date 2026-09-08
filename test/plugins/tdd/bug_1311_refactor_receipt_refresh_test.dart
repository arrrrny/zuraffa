// Issue #1311 — the run driver's refactor phase invalidates proof receipts.
//
// `zfa tdd refactor` (the run driver's refactor phase implementation,
// spawned by the two-cycle runner for phase-1 refactor steps AND phase-2b
// refactor passes) applies the fixed pass registry (resolved zfa build →
// `dart format lib/` → `dart fix --apply lib/`) AFTER make/compose/view
// recorded their proof receipts — and nothing refreshes the receipts
// afterwards, so `zfa proof check` fails with digest drift on the run's
// own generated subjects and `zfa tdd verify` refuses with NOT_ASSESSED
// (proof preflight drift).
//
// Contract pinned here (remediation):
//   B1  a sanctioned refactor that formats a receipted lib artifact
//       appends ONE proof.v1 event (command `tdd refactor`, feature
//       provenance, sanctioned/refactor markers) re-hashing the mutated
//       path to the FORMATTED bytes (FR-1, FR-5);
//   B2  after the sanctioned refactor `ProofChecker.check()` reports zero
//       `modified` findings (FR-1);
//   B3  end-to-end `zfa proof check --format json` exits 0, ok:true,
//       zero findings (FR-2);
//   B4  `zfa tdd verify --feature <f>` is NOT blocked by the proof
//       preflight drift refusal — the audit phase is reached (FR-3);
//   B5/B6/B9  backward compatibility: no mutation of receipted files →
//       no refactor receipt; unreceipted-only mutation → no refactor
//       receipt; red preflight refusal → no refactor receipt (FR-4/AS-5).
//
// RED evidence (pre-fix master): B1-B4 fail — no `tdd refactor` receipt
// exists, ProofChecker reports `modified` findings on the formatted
// artifact, proof check exits 1, verify refuses with "failed the proof
// preflight". B5/B6/B9 pass pre-fix and pin the backward-compat line.
//
// Drives the public CLI surface (`zfa tdd refactor`) against real temp
// fixture projects (TddFixture); the suite preflight + re-proof execute
// REAL `dart test` subprocesses; the build pass is pinned to the fixture's
// fake zfa via --zfa-bin (bug #689 convention shared with
// refactor_command_test.dart).
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/refactor_receipt_refresh.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late String fakeZfa;

  /// Build the CLI args for `zfa tdd refactor`, pinning the project root
  /// and the fake zfa entrypoint (bug #689 override surface).
  List<String> refactorArgs(TddFixture f, {String? feature}) => [
    'tdd',
    'refactor',
    '--project',
    f.root.path,
    '--feature',
    feature ?? f.featureName,
    '--zfa-bin',
    fakeZfa,
  ];

  /// Seed the receipt a real `zfa tdd make` run would have written for
  /// [relPath]: a proof.v1 document binding the CURRENT (pre-format)
  /// bytes, feature-scoped via `input.feature`. This reproduces the exact
  /// post-make state issue #1311 describes: receipts recorded during
  /// make, then the refactor pass rewrites the files.
  Future<void> seedMakeReceipt(TddFixture f, String relPath) async {
    final file = File(p.join(f.root.path, relPath));
    final bytes = await file.readAsBytes();
    await ReceiptStore(projectRoot: f.root.path).save(
      GenerationReceipt(
        command: 'tdd make',
        target: f.featureName,
        repro: 'zfa tdd make',
        at: DateTime.now().toUtc(),
        generatorVersion: 'tdd-fixture',
        input: {'feature': f.featureName},
        files: [
          GenerationReceiptFile(
            path: relPath,
            action: 'create',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
          ),
        ],
      ),
    );
  }

  setUp(() async {
    fx = await TddFixture.create();
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1311 — sanctioned refactor refreshes receipts (FR-1/FR-2)', () {
    test(
      'B1/B2: formatting a receipted artifact appends the refactor '
      'event with the formatted bytes; zero modified findings after',
      () async {
        await fx.seedMalformedLib();
        await seedMakeReceipt(fx, 'lib/malformed.dart');

        final before = await ReceiptStore(projectRoot: fx.root.path).loadAll();
        expect(before, hasLength(1));
        final preDigest = before.single.receipt.files.single.sha256;

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(refactorArgs(fx));

        expect(
          out,
          contains(RegExp(r'refactor: feature=\S+ outcome=(clean|refactored)')),
          reason: 'refactor output:\n$out',
        );
        expect(exitCode, 0);

        // The pass really mutated the receipted artifact (format normalized
        // the malformed bytes) — the drift precondition holds.
        final mutated = File(p.join(fx.root.path, 'lib', 'malformed.dart'));
        final mutatedDigest = crypto.sha256
            .convert(await mutated.readAsBytes())
            .toString();
        expect(mutatedDigest, isNot(preDigest));

        // FR-1: ONE appended refactor event re-hashes the mutated path.
        final after = await ReceiptStore(projectRoot: fx.root.path).loadAll();
        final events = after
            .where((r) => r.receipt.command == 'tdd refactor')
            .toList();
        expect(
          events,
          hasLength(1),
          reason: 'exactly one sanctioned refactor receipt must be appended',
        );
        final event = events.single.receipt;
        expect(event.schema, 'proof.v1');
        expect(event.input['feature'], fx.featureName);
        expect(event.input['sanctioned'], true);
        expect(event.input['refactor'], true);
        final entry = event.files.singleWhere(
          (f) => f.path == 'lib/malformed.dart',
        );
        expect(entry.action, 'update');
        expect(
          entry.sha256,
          mutatedDigest,
          reason:
              'digest must be re-derived from the FORMATTED bytes, '
              'never copied from the old receipt',
        );

        // The original make receipt stays (append-only provenance).
        expect(
          after.where((r) => r.receipt.command == 'tdd make'),
          hasLength(1),
        );

        // FR-1 assertion at the checker level: zero `modified` findings.
        final report = await ProofChecker(projectRoot: fx.root.path).check();
        expect(
          report.findings.where((f) => f.kind == ProofFinding.kindModified),
          isEmpty,
          reason:
              'the refresh must resolve the digest drift; findings: '
              '${report.findings.map((f) => f.toJson())}',
        );
      },
    );

    test(
      'B3: zfa proof check exits 0 with ok:true after the sanctioned '
      'refactor (the pass creates the drift; the refresh resolves it)',
      () async {
        await fx.seedMalformedLib();
        await seedMakeReceipt(fx, 'lib/malformed.dart');
        final runner = CliRunner(exitOnCompletion: false);

        // Sanity: BEFORE the refactor the receipts prove clean (digests
        // recorded at make time still match disk).
        await runner.runCapturing([
          '-C',
          fx.root.path,
          'proof',
          'check',
          '--format',
          'json',
        ]);
        expect(exitCode, 0, reason: 'no drift before the refactor');

        // The sanctioned run's refactor pass CREATES the drift (issue #1311
        // repro): make receipted the bytes, then format rewrote them.
        await runner.runCapturing(refactorArgs(fx));
        exitCode = 0;

        // FR-2: proof check passes after the sanctioned refactor. Pre-fix
        // this fails with `modified` digest-drift findings (red evidence).
        final out = await runner.runCapturing([
          '-C',
          fx.root.path,
          'proof',
          'check',
          '--format',
          'json',
        ]);
        expect(exitCode, 0, reason: 'post-refactor proof check: $out');
        final verdict = _lastJson(out);
        expect(verdict['ok'], true, reason: out);
        expect(verdict['valid'], true, reason: out);
        expect((verdict['findings'] as List).isEmpty, isTrue, reason: out);
      },
    );
  }, timeout: const Timeout(Duration(minutes: 8)));

  group('issue #1311 — verify not blocked by proof preflight (FR-3)', () {
    test('B4: tdd verify reaches the audit phase after the sanctioned '
        'refactor (no NOT_ASSESSED proof-preflight drift refusal)', () async {
      await fx.seedMalformedLib();
      await seedMakeReceipt(fx, 'lib/malformed.dart');
      final runner = CliRunner(exitOnCompletion: false);

      // The sanctioned run's refactor pass creates the digest drift the
      // verify proof preflight then trips over (issue #1311 repro).
      await runner.runCapturing(refactorArgs(fx));
      exitCode = 0;

      final after = await runner.runCapturing([
        'tdd',
        'verify',
        '--feature',
        fx.featureName,
        '--project',
        fx.root.path,
      ]);
      expect(
        after,
        isNot(contains('failed the proof preflight')),
        reason: 'the sanctioned refactor refreshed the receipts:\n$after',
      );
      expect(
        after,
        contains('running mutation audit'),
        reason: 'the proof preflight must let the audit run:\n$after',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 8)));

  group('issue #1311 — backward compatibility (FR-4 / AS-5)', () {
    test('B5: clean lib (no mutation) appends NO refactor receipt and '
        'leaves the receipts tree unchanged', () async {
      await fx.seedAlreadyCleanLib();
      await seedMakeReceipt(fx, 'lib/baseline.dart');
      final receiptsDir = Directory(p.join(fx.root.path, '.zfa', 'receipts'));
      final before = receiptsDir.listSync().map((e) => e.path).toSet();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));
      expect(out, contains('outcome=clean'));
      expect(exitCode, 0);

      final after = receiptsDir.listSync().map((e) => e.path).toSet();
      expect(after, before, reason: 'no receipt may be appended on a no-op');
    });

    test('B6: mutation of only UNRECEIPTED files appends NO refactor '
        'receipt', () async {
      await fx.seedMalformedLib(); // lib/malformed.dart has no receipt
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));
      expect(out, contains(RegExp(r'outcome=(clean|refactored)')));
      expect(exitCode, 0);

      final records = await ReceiptStore(projectRoot: fx.root.path).loadAll();
      expect(
        records.where((r) => r.receipt.command == 'tdd refactor'),
        isEmpty,
        reason: 'the refresh fires only when a RECEIPTED file was mutated',
      );
    });

    test('B9: a red preflight refusal appends NO refactor receipt '
        '(only a completed sanctioned pass refreshes)', () async {
      await fx.seedRedSuite();
      await seedMakeReceipt(fx, 'lib/baseline.dart');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs(fx));
      expect(out, contains('outcome=not-green'));
      expect(exitCode, isNot(0));

      final records = await ReceiptStore(projectRoot: fx.root.path).loadAll();
      expect(
        records.where((r) => r.receipt.command == 'tdd refactor'),
        isEmpty,
        reason: 'a refused refactor is not a sanctioned pass',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 8)));

  group('issue #1311 — RefactorReceiptRefresh service (FR-1/FR-4/FR-5)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('bug1311_service_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<void> seedFile(String rel, String content) async {
      final file = File(p.join(tmp.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    Future<void> seedReceipt(String rel, String content) async {
      final bytes = crypto.sha256.convert(ascii.encode(content)).toString();
      await ReceiptStore(projectRoot: tmp.path).save(
        GenerationReceipt(
          command: 'tdd make',
          target: 'feature',
          repro: 'zfa tdd make',
          at: DateTime.now().toUtc(),
          generatorVersion: 'tdd-fixture',
          input: {'feature': 'feature'},
          files: [
            GenerationReceiptFile(
              path: rel,
              action: 'create',
              sha256: bytes,
              bytes: ascii.encode(content).length,
            ),
          ],
        ),
      );
    }

    test(
      'B7: changed ∩ receipted = ∅ → fired=false, no receipt written',
      () async {
        await seedFile('lib/a.dart', 'int a() => 1;\n');
        await seedReceipt('lib/a.dart', 'int a() => 1;\n');

        final report = await RefactorReceiptRefresh.refresh(
          projectRoot: tmp.path,
          feature: 'feature',
          changedPaths: ['lib/b.dart'],
          passes: const ['format'],
        );

        expect(report.fired, isFalse);
        expect(report.refreshedPaths, isEmpty);
        final records = await ReceiptStore(projectRoot: tmp.path).loadAll();
        expect(records, hasLength(1));
        expect(records.single.receipt.command, 'tdd make');
      },
    );

    test('B8: overlap → honest re-derived digests; second event appends '
        'and latest-wins resolves to the newest digest', () async {
      await seedFile('lib/a.dart', 'int a() => 1;\n');
      await seedReceipt('lib/a.dart', 'int a() => 1;\n');

      // First sanctioned mutation (what the format pass leaves behind).
      await seedFile('lib/a.dart', 'int a() => 2;\n');
      final first = await RefactorReceiptRefresh.refresh(
        projectRoot: tmp.path,
        feature: 'feature',
        changedPaths: const ['lib/a.dart'],
        passes: const ['format'],
      );
      expect(first.fired, isTrue);
      expect(first.refreshedPaths, ['lib/a.dart']);

      final disk = File(p.join(tmp.path, 'lib', 'a.dart'));
      final diskDigest = crypto.sha256
          .convert(await disk.readAsBytes())
          .toString();

      final records = await ReceiptStore(projectRoot: tmp.path).loadAll();
      expect(records, hasLength(2)); // make + refactor event (append-only)
      final event = records.last.receipt;
      expect(event.command, 'tdd refactor');
      expect(event.input['feature'], 'feature');
      expect(event.input['sanctioned'], true);
      expect(event.input['passes'], ['format']);
      final entry = event.files.single;
      expect(entry.path, 'lib/a.dart');
      expect(entry.action, 'update');
      expect(entry.sha256, diskDigest, reason: 'digest re-derived from disk');

      // A second sanctioned mutation appends another event; the checker's
      // latest-wins then resolves to the newest digest (no drift).
      await seedFile('lib/a.dart', 'int a() => 3;\n');
      final second = await RefactorReceiptRefresh.refresh(
        projectRoot: tmp.path,
        feature: 'feature',
        changedPaths: const ['lib/a.dart'],
      );
      expect(second.fired, isTrue);

      final afterSecond = await ReceiptStore(projectRoot: tmp.path).loadAll();
      expect(afterSecond, hasLength(3));
      final report = await ProofChecker(projectRoot: tmp.path).check();
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindModified),
        isEmpty,
        reason: 'latest-wins must resolve to the newest re-hashed digest',
      );
    });

    test('B8b: a receipted path deleted by the pass is skipped honestly '
        '(no fabricated digest)', () async {
      await seedFile('lib/a.dart', 'int a() => 1;\n');
      await seedReceipt('lib/a.dart', 'int a() => 1;\n');
      // The pass (hypothetically) deleted the artifact.
      File(p.join(tmp.path, 'lib', 'a.dart')).deleteSync();

      final report = await RefactorReceiptRefresh.refresh(
        projectRoot: tmp.path,
        feature: 'feature',
        changedPaths: const ['lib/a.dart'],
      );

      expect(report.fired, isFalse, reason: 'nothing refreshable on disk');
      final report2 = await ProofChecker(projectRoot: tmp.path).check();
      expect(
        report2.findings.map((f) => f.kind),
        contains(ProofFinding.kindDeleted),
        reason: 'the deletion must stay visible to the checker',
      );
    });
  });
}

/// Parse the last JSON object printed on stdout (the proof.v1 verdict).
Map<String, dynamic> _lastJson(String stdout) {
  for (final line in stdout.split('\n').reversed) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  fail('no JSON verdict line found in:\n$stdout');
}
