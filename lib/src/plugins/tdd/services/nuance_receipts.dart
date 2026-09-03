/// `NuanceReceipts` — hand-written deltas recorded as nuance receipts in
/// the feature's provenance ledger (spec 913, phase 4; #807
/// proof-carrying pattern).
///
/// Hand-deltas are legal; UNGATED hand-deltas are not: [detect] compares
/// the realization surface's current bytes against the last provenance
/// baseline — the #807 receipt digests in `.zfa/receipts/` or the
/// ledger's own last recorded diff-hash — and every drift or missing
/// baseline is an unrecorded hand-delta the command blocks on until
/// [record] gates it with a reason. The diff-hash binds the delta to the
/// exact bytes that were gated (the #807 binding pattern).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

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

  Map<String, dynamic> toJson() => {
    'file': file,
    'reason': reason,
    'diffHash': diffHash,
    'adapter': adapter,
    'at': at,
    'recordedBy': recordedBy,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    file: json['file'] as String,
    reason: json['reason'] as String,
    diffHash: json['diffHash'] as String,
    adapter: json['adapter'] as String? ?? '',
    at: json['at'] as String,
    recordedBy: json['recordedBy'] as String? ?? 'zfa tdd realize',
  );
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
  String get path => p.join(featureDir, 'tdd', 'provenance-ledger.json');

  /// Every recorded ledger entry, oldest first.
  Future<List<LedgerEntry>> load() async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      throw NuanceReceiptException(
        'corrupted provenance ledger at $path (invalid JSON). Recovery: '
        'repair it or delete it to restart from an empty ledger.',
      );
    }
    final entries = decoded['entries'];
    if (entries is! List) return const [];
    return entries
        .map(
          (e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(growable: false);
  }

  /// Record one hand-delta: (file, reason, diff-hash). The reason is
  /// REQUIRED and non-empty — reason metadata is enforced, not optional.
  Future<LedgerEntry> record({
    required String file,
    required String reason,
    required String adapter,
    String recordedBy = 'zfa tdd realize',
  }) async {
    if (reason.trim().isEmpty) {
      throw const NuanceReceiptException(
        'a hand-delta receipt requires a non-empty --reason: reason '
        'metadata is enforced, not optional. Ungated hand-deltas are not '
        'legal.',
      );
    }
    final abs = _absolute(file);
    if (!await File(abs).exists()) {
      throw NuanceReceiptException(
        'cannot record hand-delta "$file": no such file under the project '
        'root.',
      );
    }
    final digest = crypto.sha256
        .convert(await File(abs).readAsBytes())
        .toString();
    final entry = LedgerEntry(
      file: _normalize(file),
      reason: reason,
      diffHash: digest,
      adapter: adapter,
      at: DateTime.now().toUtc().toIso8601String(),
      recordedBy: recordedBy,
    );
    final existing = await load();
    final ledgerFile = await File(path).create(recursive: true);
    final ledger = {
      'schema': 'realize-ledger.v1',
      'feature': p.basename(featureDir),
      'entries': [...existing.map((e) => e.toJson()), entry.toJson()],
    };
    await ledgerFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(ledger)}\n',
    );
    return entry;
  }

  /// Detect unrecorded hand-deltas among [files] (project-relative POSIX
  /// paths): a file whose bytes drifted from its last receipted (#807)
  /// or ledger-recorded digest, or a file with no provenance baseline at
  /// all. [exempt] files are skipped (the adapter is handled separately).
  Future<List<HandDelta>> detect({
    required List<String> files,
    Iterable<String> exempt = const [],
  }) async {
    final ledger = await load();
    final exempted = exempt.map(_normalize).toSet();
    final deltas = <HandDelta>[];
    final records = await ReceiptStore(projectRoot: projectRoot).loadAll();
    for (final raw in files) {
      final file = _normalize(raw);
      if (exempted.contains(file)) continue;
      final abs = _absolute(file);
      final f = File(abs);
      if (!await f.exists()) continue;
      final actual = crypto.sha256.convert(await f.readAsBytes()).toString();

      // Baseline 1: the ledger's own last recorded diff-hash.
      String? baseline;
      for (final entry in ledger) {
        if (entry.file == file) baseline = entry.diffHash;
      }
      // Baseline 2: the #807 receipt digest (generation provenance).
      final receipted = ReceiptStore.latestForPath(records, file);
      if (receipted != null && baseline == null) {
        baseline = receipted.entry.sha256;
      }

      if (baseline == null) {
        deltas.add(
          HandDelta(
            file: file,
            detail:
                'no provenance baseline (neither a receipt nor a ledger '
                'entry) — record it with --hand-delta or revert it',
            actualHash: actual,
          ),
        );
      } else if (baseline != actual) {
        deltas.add(
          HandDelta(
            file: file,
            detail: 'digest drift from the last provenance record',
            expectedHash: baseline,
            actualHash: actual,
          ),
        );
      }
    }
    return deltas;
  }

  String _absolute(String rel) => p.join(projectRoot, _normalize(rel));

  static String _normalize(String rel) =>
      p.posix.normalize(p.posix.joinAll(p.split(rel))).replaceAll('\\', '/');
}
