// Issue #1327 — the run driver's post-make phases invalidate the
// cycle-log receipt (the #1311 fix did not cover the log itself).
//
// `zfa tdd make` appends green evidence to `specs/<f>/tdd/cycle-log.md`
// and receipts the log at those bytes. The run driver's post-make phases
// append to the SAME log afterwards — the refactor step's evidence and
// the meta run's unified two-cycle journal entry — and nothing re-receipts
// it. `ProofChecker` re-derives every recorded digest, so every sanctioned
// complete run fails `zfa proof check` with exactly one `modified` finding
// on the log, and the printed remedy (`zfa tdd make`) is a no-op on the
// completed behavior (outcome=skipped, never re-receipts).
//
// Contract pinned here (remediation — the TERMINAL-RECEIPT branch of the
// issue's criterion-2 either/or; the append-prefix checker exemption is
// rejected because it would also erase the incomplete-run drift findings
// that criterion 4 pins as expected):
//   B1  a sanctioned complete meta run ends with ONE terminal proof.v1
//       receipt (command `tdd run`, `input.feature`, sanctioned/terminal
//       markers) re-hashing the log to its FINAL bytes (FR-1, FR-5);
//   B2  end-to-end `zfa proof check --format json` exits 0, ok:true,
//       zero findings after the sanctioned complete run (FR-2);
//   B3  `ProofChecker.check()` reports zero `modified` findings after the
//       run (latest-wins resolves the terminal receipt) (FR-1);
//   B4  a standalone `zfa tdd run-engine` that completes from a receipted
//       pre-run log state ends with the same terminal coverage (command
//       `tdd run-engine`) and proof check passes (FR-1);
//   B5  backward compatibility: a run that is NOT complete writes NO
//       terminal receipt and the `modified` finding on the log REMAINS
//       (criterion 4 — expected and correct; green pre-fix, pinned).
//
// RED evidence (pre-fix master): B1-B4 fail — no terminal receipt exists,
// proof check exits 1 with the issue's exact finding shape on
// specs/<f>/tdd/cycle-log.md. B5 passes pre-fix and pins the
// backward-compat line.
//
// Drives the public CLI surface (`zfa tdd run` / `run-engine`) against a
// real temp fixture project (TddFixture); the steps are the fixture's
// scripted fake zfa (run_command_test.dart conventions). The seeded
// `tdd make` receipt stands for the real make's log coverage — the fake
// steps reproduce the log appends but not the digest computation.
@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import 'helpers/tdd_fixture.dart';

/// The header bytes a first `CycleLog.append` writes before its first
/// entry — the pre-run state a `tdd make` receipt can cover.
const String cycleLogHeader =
    '# Cycle Log\n\nAppend only. Newest last. Every entry\'s `red` block '
    'is the evidence that the test existed and failed before the '
    'implementation.\n\n';

void main() {
  late TddFixture fx;
  const feature = '1327-cycle-log-receipt';

  Future<String> drive({List<String> extraArgs = const []}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
      ...extraArgs,
    ]);
  }

  Future<String> driveEngine() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run-engine',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  Future<String> proofCheckJson() => CliRunner(
    exitOnCompletion: false,
  ).runCapturing(['-C', fx.root.path, 'proof', 'check', '--format', 'json']);

  /// Seed the receipt standing for the last real `zfa tdd make` coverage
  /// of the cycle log: a proof.v1 document binding the CURRENT on-disk
  /// bytes of `specs/<f>/tdd/cycle-log.md`, feature-scoped via
  /// `input.feature` — the exact post-make state issue #1327 describes
  /// (the receipt predates the driver's post-make appends).
  Future<void> seedMakeReceipt() async {
    final file = File(fx.cycleLogPath);
    final bytes = await file.readAsBytes();
    await ReceiptStore(projectRoot: fx.root.path).save(
      GenerationReceipt(
        command: 'tdd make',
        target: feature,
        repro: 'zfa tdd make',
        at: DateTime.now().toUtc(),
        generatorVersion: 'tdd-fixture',
        input: {'feature': feature},
        files: [
          GenerationReceiptFile(
            path: 'specs/$feature/tdd/cycle-log.md',
            action: 'update',
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
          ),
        ],
      ),
    );
  }

  List<ReceiptRecord> terminalReceipts(List<ReceiptRecord> records) => records
      .where(
        (r) =>
            r.receipt.command == 'tdd run' &&
            r.receipt.input['terminal'] == true,
      )
      .toList();

  Future<int> terminalReceiptCount() async => terminalReceipts(
    await ReceiptStore(projectRoot: fx.root.path).loadAll(),
  ).length;

  Map<String, dynamic> lastJson(String stdout) {
    for (final line in stdout.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    fail('no JSON verdict line found in:\n$stdout');
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-002',
        description: 'second behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1327 — complete meta run ends with a terminal receipt', () {
    test('B1: the terminal receipt re-hashes the log to its final bytes; '
        'the make receipt stays (append-only provenance)', () async {
      // Run #1 drives the feature to complete: the fake steps append
      // red + green evidence; the meta run appends the unified journal
      // entry. No receipts exist yet, so proof check is trivially ok.
      final out1 = await drive();
      expect(exitCode, 0, reason: out1);

      // The receipt that stands for the last `tdd make` coverage of
      // the log — written BEFORE the next run's post-make appends.
      // (Run #1, itself complete, already appended its own terminal
      // receipt — the contract is exactly one per complete run.)
      final terminalsBefore = await terminalReceiptCount();
      await seedMakeReceipt();

      // Run #2 is a sanctioned complete run whose ONLY log mutation is
      // the driver's own unified journal entry appended AFTER that
      // receipt (the vacuous re-drive spawns no steps — evidence beats
      // state). This is the issue #1327 drift precondition.
      fx.clearStepInvocations();
      final logBytesBefore = File(fx.cycleLogPath).lengthSync();
      final out2 = await drive();
      expect(exitCode, 0, reason: out2);
      expect(out2, contains('result=complete'), reason: out2);
      expect(fx.stepInvocations(), isEmpty, reason: out2);
      final logBytesAfter = File(fx.cycleLogPath).lengthSync();
      expect(
        logBytesAfter,
        greaterThan(logBytesBefore),
        reason: 'the unified journal entry appended after the receipt',
      );

      // FR-1: exactly ONE terminal receipt per complete run, and the
      // newest one re-hashes the log's FINAL bytes.
      final records = await ReceiptStore(projectRoot: fx.root.path).loadAll();
      final terminal = terminalReceipts(records);
      expect(
        terminal.length,
        terminalsBefore + 1,
        reason:
            'exactly one terminal cycle-log receipt must be appended '
            'by the complete run; receipts: '
            '${records.map((r) => r.fileName)}',
      );
      final event = terminal.last.receipt;
      expect(event.schema, 'proof.v1');
      expect(event.command, 'tdd run');
      expect(event.target, feature);
      expect(event.input['feature'], feature);
      expect(event.input['sanctioned'], true);
      expect(event.input['terminal'], true);
      final entry = event.files.singleWhere(
        (f) => f.path == 'specs/$feature/tdd/cycle-log.md',
      );
      expect(entry.action, 'update');
      final diskDigest = crypto.sha256
          .convert(File(fx.cycleLogPath).readAsBytesSync())
          .toString();
      expect(
        entry.sha256,
        diskDigest,
        reason:
            'digest must be re-derived from the log\'s FINAL bytes, '
            'never copied from the stale make receipt',
      );

      // The make receipt stays (append-only provenance).
      expect(
        records.where((r) => r.receipt.command == 'tdd make'),
        hasLength(1),
      );
    });

    test(
      'B2: zfa proof check exits 0 with ok:true after the sanctioned '
      'complete run (pre-fix: one modified finding — the issue repro)',
      () async {
        final out1 = await drive();
        expect(exitCode, 0, reason: out1);
        await seedMakeReceipt();

        // Sanity: BEFORE the post-receipt appends the receipts prove
        // clean (the seeded digest matches the disk bytes).
        final clean = await proofCheckJson();
        expect(exitCode, 0, reason: clean);

        // The sanctioned run appends the unified journal entry AFTER the
        // receipt — pre-fix this leaves the issue's exact drift finding;
        // post-fix the terminal receipt resolves it (FR-2).
        final out2 = await drive();
        expect(exitCode, 0, reason: out2);

        final out = await proofCheckJson();
        expect(exitCode, 0, reason: 'post-run proof check: $out');
        final verdict = lastJson(out);
        expect(verdict['ok'], true, reason: out);
        expect(verdict['valid'], true, reason: out);
        expect((verdict['findings'] as List).isEmpty, isTrue, reason: out);
      },
    );

    test('B3: ProofChecker reports zero modified findings after the '
        'complete run (latest-wins resolves the terminal receipt)', () async {
      final out1 = await drive();
      expect(exitCode, 0, reason: out1);
      await seedMakeReceipt();

      final out2 = await drive();
      expect(exitCode, 0, reason: out2);

      final report = await ProofChecker(projectRoot: fx.root.path).check();
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindModified),
        isEmpty,
        reason:
            'the terminal receipt must resolve the digest drift; '
            'findings: ${report.findings.map((f) => f.toJson())}',
      );
    });
  });

  group('issue #1327 — standalone engine lane terminal receipt', () {
    test('B4: a completed zfa tdd run-engine ends with the log covered '
        '(command tdd run-engine); proof check passes', () async {
      // Pre-run state: the log exists with only the header, receipted by
      // the make receipt that stands for the last pre-run coverage.
      await File(fx.cycleLogPath).parent.create(recursive: true);
      File(fx.cycleLogPath).writeAsStringSync(cycleLogHeader);
      await seedMakeReceipt();

      // The lane drives B-001 fully: verify-red appends red evidence,
      // make appends green evidence — both AFTER the receipt (the drift
      // precondition). Pre-fix the run ends with the finding; post-fix
      // the lane's terminal receipt resolves it.
      final out = await driveEngine();
      expect(exitCode, 0, reason: out);
      expect(out, contains('result=complete'), reason: out);

      final records = await ReceiptStore(projectRoot: fx.root.path).loadAll();
      final terminal = records
          .where(
            (r) =>
                r.receipt.command == 'tdd run-engine' &&
                r.receipt.input['terminal'] == true,
          )
          .toList();
      expect(
        terminal,
        hasLength(1),
        reason:
            'the completed engine lane must close with a terminal '
            'cycle-log receipt; receipts: '
            '${records.map((r) => r.fileName)}',
      );
      final entry = terminal.single.receipt.files.singleWhere(
        (f) => f.path == 'specs/$feature/tdd/cycle-log.md',
      );
      final diskDigest = crypto.sha256
          .convert(File(fx.cycleLogPath).readAsBytesSync())
          .toString();
      expect(entry.sha256, diskDigest);

      final proofOut = await proofCheckJson();
      expect(exitCode, 0, reason: 'post-lane proof check: $proofOut');
      final verdict = lastJson(proofOut);
      expect(verdict['ok'], true, reason: proofOut);
      expect((verdict['findings'] as List).isEmpty, isTrue, reason: proofOut);
    });
  });

  group('issue #1327 — backward compatibility (criterion 4)', () {
    test('B5: a run that stops early writes NO terminal receipt and the '
        'modified finding on the log REMAINS', () async {
      final out1 = await drive();
      expect(exitCode, 0, reason: out1);
      await seedMakeReceipt();
      final terminalsBefore = await terminalReceiptCount();

      // A NEW pending behavior whose make stops the run — but only AFTER
      // its verify-red appended the red evidence to the log (the
      // post-receipt mutation a non-complete run legitimately leaves
      // unreceipted).
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-003',
          description: 'third behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.setStepOutcome('make', 'B-003', 'regression');

      final out2 = await drive();
      expect(exitCode, isNot(0), reason: out2);
      expect(out2, contains('result=stopped'), reason: out2);

      // FR-3: no terminal receipt may be appended by the stopped run —
      // the count is exactly what the earlier complete run left.
      expect(await terminalReceiptCount(), terminalsBefore);

      // And the drift the stopped run created REMAINS visible to the
      // checker (the honest record that the run mutated the log after
      // its receipts) — never papered over.
      final report = await ProofChecker(projectRoot: fx.root.path).check();
      final logFindings = report.findings.where(
        (f) =>
            f.kind == ProofFinding.kindModified &&
            f.path == 'specs/$feature/tdd/cycle-log.md',
      );
      expect(
        logFindings,
        hasLength(1),
        reason:
            'a non-complete run keeps its receipt drift (criterion 4); '
            'findings: ${report.findings.map((f) => f.toJson())}',
      );
    });
  });
}
