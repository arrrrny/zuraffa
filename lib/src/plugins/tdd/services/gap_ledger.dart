/// Gap ledger service (spec 051-corpus-harness, FR-007/FR-008).
///
/// Append-only persistence for `.zfa/corpus/gap-ledger.json`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/gap_ledger_entry.dart';

class GapLedgerTotals {
  const GapLedgerTotals({
    required this.total,
    required this.unresolved,
    required this.filed,
    required this.resolved,
    required this.blocking,
  });

  final int total;
  final int unresolved;
  final int filed;
  final int resolved;
  final int blocking;
}

class GapLedger {
  GapLedger(this.projectRoot);

  final String projectRoot;

  String get _path => p.join(projectRoot, '.zfa', 'corpus', 'gap-ledger.json');

  /// Load entries, or an empty list if the file does not exist.
  Future<List<GapLedgerEntry>> load() async {
    final file = File(_path);
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>? ?? [];
    return entries
        .map((e) => GapLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Append a stop entry. Atomic via temp+rename.
  Future<void> append(GapLedgerEntry entry) async {
    final entries = await load();
    entries.add(entry);
    await _save(entries);
  }

  /// Append a resolution entry for a previously-stopped feature.
  Future<void> appendResolution({
    required String feature,
    required String timestamp,
  }) async {
    final entry = GapLedgerEntry(
      feature: feature,
      outcome: 'resolved',
      command: '(corpus re-run)',
      timestamp: timestamp,
      resolution: 'resolved',
    );
    await append(entry);
  }

  /// Compute ledger totals.
  GapLedgerTotals totals(List<GapLedgerEntry> entries) {
    var unresolved = 0;
    var filed = 0;
    var resolved = 0;
    for (final e in entries) {
      if (e.resolution == 'resolved') {
        resolved++;
      } else if (e.issueLink != null) {
        filed++;
      } else {
        unresolved++;
      }
    }
    return GapLedgerTotals(
      total: entries.length,
      unresolved: unresolved,
      filed: filed,
      resolved: resolved,
      blocking: unresolved,
    );
  }

  Future<void> _save(List<GapLedgerEntry> entries) async {
    final map = {
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    await Directory(p.dirname(_path)).create(recursive: true);
    final tmp = File('$_path.tmp');
    await tmp.writeAsString(jsonStr);
    await tmp.rename(_path);
  }
}
