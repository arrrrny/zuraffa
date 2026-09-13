/// `HandDeltaReceipts` — the sanctioned hand-delta re-receipt event
/// (spec 1423, issue #1423).
///
/// The designed hand-delta protocol (issue #1308) mutates receipted
/// artifacts AFTER the gen receipt was written: the run driver's
/// `<id>:hand` stop prescribes hand-written assertions in the generated
/// test and a hand-implemented subject, and the cycle closes through the
/// certification transitions — `zfa tdd verify-red <id> --re-certify`
/// (issue #1162) and make's skip transition (issue #694). Both used to
/// receipt ONLY the cycle log, so `ProofChecker`'s latest-wins still
/// resolved the pre-hand-delta gen bytes and `zfa tdd verify`'s proof
/// preflight refused the feature (`digest mismatch: receipt says …, disk
/// has … (action: create)` — NOT_ASSESSED). Verify was unreachable for
/// hand-delta'd features, and the prescribed remedy (`zfa tdd gen`)
/// regenerates the guard test and destroys the certified work (the #1375
/// destructive-remedy class).
///
/// The remediation appends ONE proof.v1 "sanctioned hand-delta" receipt
/// covering exactly the behavior's receipted test/subject paths whose
/// current disk digest differs from the latest recorded digest, re-hashed
/// from the CURRENT on-disk bytes — the same append-only pattern the
/// refactor pass uses for reformatted subjects (issue #1311,
/// `RefactorReceiptRefresh`). `ProofChecker` applies latest-wins per
/// artifact path (receipts load oldest-first), so the appended event
/// supersedes the older generation digests WITHOUT any change to the check
/// algorithm, the verify gate semantics, the preflight, the engine cycle,
/// or the state machine. The original gen receipts stay on disk
/// (append-only provenance).
///
/// Backward compatibility: the refresh fires ONLY when a receipted path
/// actually drifted (the latest receipt digest differs from the disk
/// digest). A transition over an unchanged pair — or over paths no receipt
/// covers — writes nothing at all: provenance is never fabricated for an
/// unreceipted path, and a file that vanished is skipped honestly (the
/// surviving receipts surface it as a `deleted` finding, never a
/// fabricated digest).
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';
import 'tdd_generation_receipt.dart';

/// The outcome of one hand-delta refresh attempt.
class HandDeltaReceiptReport {
  const HandDeltaReceiptReport({
    required this.fired,
    required this.receiptedPaths,
  });

  static const none = HandDeltaReceiptReport(fired: false, receiptedPaths: []);

  /// True when a sanctioned hand-delta receipt was appended.
  final bool fired;

  /// The receipted paths the event re-hashed (project-relative POSIX).
  final List<String> receiptedPaths;
}

class HandDeltaReceipts {
  /// Re-receipts the hand-delta drift on [artifactPaths] (the behavior's
  /// recorded test/subject paths, any form — machine-absolute legacy or
  /// project-relative per issue #1397).
  ///
  /// [command] and [transition] name the certifying verb (`tdd make` /
  /// `skip`, `tdd verify-red --re-certify` / `re-certify`) so the appended
  /// event's provenance names the transition that blessed the current
  /// bytes. [feature] scopes the event the way the generation verbs do
  /// (`input.feature`) so `zfa tdd verify`'s feature-scoped proof
  /// preflight recognizes the refreshed paths.
  static Future<HandDeltaReceiptReport> refresh({
    required String projectRoot,
    required String? feature,
    required String behaviorId,
    required String command,
    required String transition,
    required Iterable<String> artifactPaths,
  }) async {
    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();
    if (records.isEmpty || artifactPaths.isEmpty) {
      return HandDeltaReceiptReport.none;
    }

    // Latest-wins digest per receipted path — the same resolution
    // `ProofChecker` applies, so "drifted" here means exactly "the
    // checker will report `modified` for this path".
    final latest = <String, String>{};
    for (final record in records) {
      for (final entry in record.receipt.files) {
        latest[entry.path] = entry.sha256;
      }
    }
    if (latest.isEmpty) return HandDeltaReceiptReport.none;

    final drifted = <String, String>{}; // absolute path -> project-relative
    for (final raw in artifactPaths) {
      final relative = _relativePosix(raw, projectRoot);
      // Only ALREADY-RECEIPTED paths: the hand-delta class is drift on a
      // receipted artifact. A path no receipt covers is not this spec's
      // problem (the preflight's missing-receipt gate owns it) and
      // fabricating provenance for it would be dishonest.
      final recorded = latest[relative];
      if (recorded == null) continue;
      final file = File(p.join(projectRoot, relative));
      // A vanished receipted artifact is skipped honestly: the checker
      // keeps reporting `deleted`, never a fabricated digest.
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final digest = crypto.sha256.convert(bytes).toString();
      // Idempotence: fire only on actual drift. A transition over an
      // unchanged pair appends nothing — the gen receipt still validates.
      if (recorded == digest) continue;
      // FR-5 (honest provenance): the digest is re-derived from the
      // on-disk bytes at event time, never copied from the old receipt.
      drifted[file.path] = relative;
    }
    if (drifted.isEmpty) return HandDeltaReceiptReport.none;

    await TddGenerationReceipts.write(
      projectRoot: projectRoot,
      command: command,
      target: behaviorId,
      feature: feature,
      files: {for (final entry in drifted.entries) entry.key: 'update'},
      input: {
        'sanctioned': true,
        'hand_delta': true,
        'transition': transition,
        'behavior': behaviorId,
      },
    );
    return HandDeltaReceiptReport(
      fired: true,
      receiptedPaths: drifted.values.toList()..sort(),
    );
  }

  /// Best-effort variant for the certifying transitions (mirrors
  /// [RefactorReceiptRefresh.refreshBestEffort] and
  /// [TddGenerationReceipts.writeBestEffort]): a receipt-write failure
  /// must never flip a sanctioned hand-delta certification to a failure.
  /// The loss is reported on stderr so it is never silent, and it stays
  /// fail-visible through `zfa proof check` (the stale digests still
  /// drift).
  static Future<HandDeltaReceiptReport> refreshBestEffort({
    required String projectRoot,
    required String? feature,
    required String behaviorId,
    required String command,
    required String transition,
    required Iterable<String> artifactPaths,
  }) async {
    try {
      return await refresh(
        projectRoot: projectRoot,
        feature: feature,
        behaviorId: behaviorId,
        command: command,
        transition: transition,
        artifactPaths: artifactPaths,
      );
    } catch (e) {
      stderr.writeln(
        'zfa $command: warning: hand-delta proof receipt not written '
        '($e) — re-run the certification to restore the provenance record '
        '(issue #1423).',
      );
      return HandDeltaReceiptReport.none;
    }
  }

  static String _relativePosix(String filePath, String from) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: from)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
