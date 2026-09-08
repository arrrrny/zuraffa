/// `CycleLogTerminalReceipt` — the run driver's terminal cycle-log
/// receipt (issue #1327).
///
/// The run driver's post-make phases append evidence to
/// `specs/<f>/tdd/cycle-log.md` AFTER the last `tdd make` receipt covering
/// the log was written: the refactor step appends its evidence (the #1311
/// refresh covers only the pass registry's `lib/` mutations, never the
/// log) and the meta run appends the unified two-cycle journal entry.
/// `ProofChecker` re-derives every recorded digest, so every sanctioned
/// complete run failed `zfa proof check` with exactly one `modified`
/// finding on the log — and the printed remedy (`zfa tdd make`) was a
/// no-op on the completed behavior (outcome=skipped, never re-receipts):
/// the same unexecutable-remedy class as #1311.
///
/// The remediation appends ONE terminal proof.v1 receipt re-hashing the
/// log to its FINAL bytes at run end, so `ProofChecker`'s latest-wins
/// resolution (receipts load oldest-first, the last receipt per artifact
/// path wins) makes the fresh digest authoritative. `result=complete` now
/// implies `zfa proof check` passes with zero digest-drift findings.
///
/// Backward compatibility (issue #1327 criterion 4): the terminal receipt
/// fires ONLY on a complete run — the callers gate on `result=complete`.
/// A run that stopped early keeps its receipt drift, which stays the
/// honest record that the run mutated the log after its receipts. The
/// append-prefix checker exemption was deliberately NOT implemented: the
/// checker sees only bytes and cannot distinguish a complete run's
/// post-receipt appends from a stopped run's, so prefix verification
/// would erase the incomplete-run findings criterion 4 pins as
/// expected-and-correct.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'tdd_generation_receipt.dart';

class CycleLogTerminalReceipt {
  /// Appends ONE terminal proof.v1 receipt covering
  /// `specs/<feature>/tdd/cycle-log.md`, re-hashed from the log's CURRENT
  /// (final) on-disk bytes — never copied from an older receipt (honest
  /// provenance). [command] names the driving invocation (`tdd
  /// run`, `tdd run-engine`, `tdd run-skin`) so the receipt's repro line
  /// re-enters the same sanctioned run.
  ///
  /// Best-effort (mirrors [TddGenerationReceipts.writeBestEffort] and the
  /// #1311 `RefactorReceiptRefresh.refreshBestEffort`): a receipt-write
  /// failure is reported on stderr and never fatal to the run that
  /// already drove — the loss stays fail-visible through
  /// `zfa proof check`. A missing log file writes nothing (there is
  /// nothing to cover).
  static Future<void> refreshBestEffort({
    required String projectRoot,
    required String feature,
    required String command,
  }) async {
    try {
      await TddGenerationReceipts.write(
        projectRoot: projectRoot,
        command: command,
        target: feature,
        feature: feature,
        files: {
          p.join(projectRoot, 'specs', feature, 'tdd', 'cycle-log.md'):
              'update',
        },
        input: {'sanctioned': true, 'terminal': true},
      );
    } catch (e) {
      stderr.writeln(
        'zfa $command: warning: terminal cycle-log receipt not written '
        '($e) — re-run to restore the provenance record (issue #1327).',
      );
    }
  }
}
