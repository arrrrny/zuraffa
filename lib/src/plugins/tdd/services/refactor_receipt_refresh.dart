/// `RefactorReceiptRefresh` — the sanctioned refactor provenance event
/// (issue #1311).
///
/// The run driver's refactor phase (the fixed pass registry in
/// `zfa tdd refactor`: resolved zfa build → `dart format lib/` →
/// `dart fix --apply lib/`) rewrites receipted artifacts AFTER
/// make/compose/view recorded their proof receipts. `ProofChecker`
/// re-derives every recorded digest against the current tree, so every
/// sanctioned run that applies a refactor used to fail `zfa proof check`
/// with digest drift and block `zfa tdd verify` at its proof preflight
/// (NOT_ASSESSED) — the two subsystems the workflow tells agents to run
/// before committing could not both pass.
///
/// The remediation appends ONE proof.v1 "sanctioned refactor" receipt
/// covering exactly the receipted paths the passes actually mutated,
/// re-hashed from the CURRENT on-disk bytes. `ProofChecker` applies
/// latest-wins per artifact path (receipts load oldest-first), so the
/// appended event supersedes the older generation digests WITHOUT any
/// change to the check algorithm, the verify gate semantics, the engine
/// cycle, or make/compose/view. The original generation receipts stay on
/// disk (append-only provenance).
///
/// Backward compatibility: the refresh fires ONLY when a receipted file
/// was actually mutated (the changed∩receipted intersection is non-empty).
/// A refactor that mutates nothing — or only unreceipted files — writes
/// nothing at all.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';
import 'tdd_generation_receipt.dart';

/// The outcome of one refresh attempt.
class RefactorReceiptRefreshReport {
  const RefactorReceiptRefreshReport({
    required this.fired,
    required this.refreshedPaths,
  });

  static const none = RefactorReceiptRefreshReport(
    fired: false,
    refreshedPaths: [],
  );

  /// True when a sanctioned refactor receipt was appended.
  final bool fired;

  /// The receipted paths the event re-hashed (project-relative POSIX).
  final List<String> refreshedPaths;
}

class RefactorReceiptRefresh {
  /// Intersects [changedPaths] (the pass-registry-changed paths the
  /// refactor command recorded from its before/after tree snapshot, e.g.
  /// the `lib/` diff) with every proof.v1 receipted artifact path under
  /// `<projectRoot>/.zfa/receipts/` and, when the intersection is
  /// non-empty, appends one sanctioned refactor receipt re-hashing those
  /// paths to their current bytes.
  ///
  /// [feature] scopes the event the same way the generation verbs do
  /// (`input.feature`) so `zfa tdd verify`'s feature-scoped proof
  /// preflight recognizes the refreshed paths. [passes] names the pass
  /// registry actions that ran (build/format/fix) for the provenance
  /// record. Files that vanished between the pass and the refresh are
  /// skipped honestly — the surviving receipts surface them as `deleted`
  /// findings, never a fabricated digest.
  static Future<RefactorReceiptRefreshReport> refresh({
    required String projectRoot,
    required String? feature,
    required Iterable<String> changedPaths,
    List<String> passes = const <String>[],
  }) async {
    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();
    final receipted = <String>{
      for (final record in records)
        for (final entry in record.receipt.files) entry.path,
    };
    if (receipted.isEmpty || changedPaths.isEmpty) {
      return RefactorReceiptRefreshReport.none;
    }

    final touched =
        changedPaths
            .map((path) => _relativePosix(path, projectRoot))
            .where(receipted.contains)
            .toList()
          ..sort();
    if (touched.isEmpty) return RefactorReceiptRefreshReport.none;

    // Re-hash from the on-disk bytes at event time — never copy the old
    // receipt's digest (FR-5: honest provenance).
    final files = <String, String>{};
    for (final path in touched) {
      final file = File(p.join(projectRoot, path));
      if (!file.existsSync()) continue;
      files[file.path] = 'update';
    }
    if (files.isEmpty) return RefactorReceiptRefreshReport.none;

    await TddGenerationReceipts.write(
      projectRoot: projectRoot,
      command: 'tdd refactor',
      target: feature ?? 'refactor',
      feature: feature,
      files: files,
      input: {'sanctioned': true, 'refactor': true, 'passes': passes},
    );
    return RefactorReceiptRefreshReport(fired: true, refreshedPaths: touched);
  }

  /// Best-effort variant for the refactor command: a receipt-write
  /// failure must never flip a sanctioned refactor to a failure (mirrors
  /// [TddGenerationReceipts.writeBestEffort]). The loss is reported on
  /// stderr so it is never silent, and it stays fail-visible through
  /// `zfa proof check` (the stale digests still drift).
  static Future<RefactorReceiptRefreshReport> refreshBestEffort({
    required String projectRoot,
    required String? feature,
    required Iterable<String> changedPaths,
    List<String> passes = const <String>[],
  }) async {
    try {
      return await refresh(
        projectRoot: projectRoot,
        feature: feature,
        changedPaths: changedPaths,
        passes: passes,
      );
    } catch (e) {
      stderr.writeln(
        'zfa tdd refactor: warning: proof receipt refresh not written '
        '($e) — re-run to restore the provenance record (issue #1311).',
      );
      return RefactorReceiptRefreshReport.none;
    }
  }

  static String _relativePosix(String filePath, String from) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: from)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
