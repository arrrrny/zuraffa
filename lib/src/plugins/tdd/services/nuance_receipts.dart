/// `NuanceReceipts` — hand-written deltas recorded as nuance receipts in
/// the feature's provenance ledger (spec 913, phase 4; #807
/// proof-carrying pattern).
///
/// STUB (red phase): every member throws until the green phase implements
/// the ledger contract.
library;

import '../../../core/project/receipt_store.dart';

/// Raised when the ledger contract is violated: an empty reason (reason
/// metadata is enforced, never optional) or an unreadable file.
class NuanceReceiptException implements Exception {
  const NuanceReceiptException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One ledger row: a hand-written delta, gated with its reason and bound
/// to the exact bytes via its diff-hash (#807 pattern).
class LedgerEntry {
  const LedgerEntry({
    required this.file,
    required this.reason,
    required this.diffHash,
    required this.adapter,
    required this.at,
    this.recordedBy = 'zfa tdd realize',
  });

  /// Project-relative POSIX path of the hand-written file.
  final String file;

  /// The non-empty reason the delta is legal.
  final String reason;

  /// SHA-256 of the file's bytes at record time.
  final String diffHash;

  /// The adapter the realize run bound.
  final String adapter;

  /// ISO-8601 UTC timestamp.
  final String at;

  final String recordedBy;

  Map<String, dynamic> toJson() => throw UnimplementedError();

  factory LedgerEntry.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();
}

/// One detected (unrecorded) hand-delta.
class HandDelta {
  const HandDelta({
    required this.file,
    required this.detail,
    this.expectedHash,
    this.actualHash,
  });

  /// Project-relative POSIX path.
  final String file;

  /// Why it was flagged: digest drift or no provenance baseline at all.
  final String detail;

  final String? expectedHash;
  final String? actualHash;
}

class NuanceReceipts {
  NuanceReceipts({required this.featureDir, required this.projectRoot});

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The target project root.
  final String projectRoot;

  /// The ledger path: `specs/<feature>/tdd/provenance-ledger.json`.
  String get path => throw UnimplementedError();

  /// Every recorded ledger entry, oldest first.
  Future<List<LedgerEntry>> load() => throw UnimplementedError();

  /// Record one hand-delta: (file, reason, diff-hash). The reason is
  /// REQUIRED and non-empty — reason metadata is enforced, not optional.
  Future<LedgerEntry> record({
    required String file,
    required String reason,
    required String adapter,
    String recordedBy = 'zfa tdd realize',
  }) => throw UnimplementedError();

  /// Detect unrecorded hand-deltas among [files] (project-relative POSIX
  /// paths): a file whose bytes drifted from its last receipted (#807)
  /// or ledger-recorded digest, or a file with no provenance baseline at
  /// all. [exempt] files are skipped (the adapter is handled separately).
  Future<List<HandDelta>> detect({
    required List<String> files,
    Iterable<String> exempt = const [],
  }) => throw UnimplementedError();
}
