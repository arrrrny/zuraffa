/// `GapLedgerStore` — the append-only gap ledger at
/// `.zfa/corpus/gap-ledger.json` (spec 051-corpus-harness, FR-007):
/// load → append → atomic rename; history is never rewritten (US4.AC2).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/corpus_ledger.dart';
import '../models/corpus_progress.dart';

class GapLedgerStore {
  GapLedgerStore(this.projectRoot);

  /// The driven app's project root.
  final String projectRoot;

  String get path => p.join(projectRoot, '.zfa', 'corpus', 'gap-ledger.json');

  /// Load every entry (empty when the file is absent). Corruption is a
  /// [CorpusCorruptException] naming the file and the recovery path.
  Future<List<GapLedgerEntry>> load() async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw _corrupt('invalid JSON: ${e.message}');
    }
    if (decoded is! List) {
      throw _corrupt('top-level value is not a list');
    }
    try {
      return decoded
          .map((e) => GapLedgerEntry.fromJson(e))
          .toList(growable: false);
    } on FormatException catch (e) {
      throw _corrupt(e.message);
    }
  }

  /// Append a gap entry (the runner's only write on a stop). The id is
  /// assigned monotonically (`gap-###`).
  Future<GapLedgerEntry> appendGap({
    required String feature,
    String? behavior,
    String? step,
    String? outcome,
    String? failingCommand,
  }) async {
    final entries = await load();
    final next = _nextId(entries, GapLedgerKind.gap);
    final entry = GapLedgerEntry.gap(
      id: next,
      at: _now(),
      feature: feature,
      behavior: behavior,
      step: step,
      outcome: outcome,
      failingCommand: failingCommand,
    );
    await _persist([...entries, entry]);
    return entry;
  }

  /// Append a resolution entry closing [resolves] (a previously-gapped
  /// feature later passing — a NEW entry, never an edit).
  Future<GapLedgerEntry> appendResolution({
    required String feature,
    required String resolves,
  }) async {
    final entries = await load();
    final next = _nextId(entries, GapLedgerKind.resolution);
    final entry = GapLedgerEntry.resolution(
      id: next,
      at: _now(),
      feature: feature,
      resolves: resolves,
    );
    await _persist([...entries, entry]);
    return entry;
  }

  /// The next id in the entry's series (`gap-007` / `res-002`).
  static String _nextId(List<GapLedgerEntry> entries, GapLedgerKind kind) {
    final prefix = kind == GapLedgerKind.gap ? 'gap' : 'res';
    var max = 0;
    for (final entry in entries) {
      if (entry.kind != kind) continue;
      final number = int.tryParse(entry.id.split('-').lastOrNull ?? '');
      if (number != null && number > max) max = number;
    }
    return '$prefix-${(max + 1).toString().padLeft(3, '0')}';
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Persist [entries] atomically (temp + rename). The encoder keeps a
  /// fixed field order, so previously-appended entries serialize
  /// byte-identically across appends (U13).
  Future<void> _persist(List<GapLedgerEntry> entries) async {
    await Directory(p.dirname(path)).create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        entries.map((e) => e.toJson()).toList(),
      ),
    );
    await tmp.rename(path);
  }

  Never _corrupt(String cause) => throw CorpusCorruptException(
    'corrupted $path ($cause). Recovery: repair it to valid gap-ledger '
    'JSON — the ledger is append-only history, so deleting it destroys '
    'the gap record (prefer repair).',
  );
}
