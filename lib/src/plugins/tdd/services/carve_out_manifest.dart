/// Carve-out manifest service (spec 051-corpus-harness).
///
/// Reads and writes `.zfa/corpus/carve-out.json` — the versioned exemption
/// list for the provenance audit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/carve_out_entry.dart';

class CarveOutManifest {
  CarveOutManifest(this.projectRoot);

  final String projectRoot;

  String get _path => p.join(projectRoot, '.zfa', 'corpus', 'carve-out.json');

  /// Load the manifest, or an empty manifest if the file does not exist.
  Future<List<CarveOutEntry>> load() async {
    final file = File(_path);
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>? ?? [];
    return entries
        .map((e) => CarveOutEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save the manifest atomically.
  Future<void> save(List<CarveOutEntry> entries) async {
    final map = {'entries': entries.map((e) => e.toJson()).toList()};
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    await Directory(p.dirname(_path)).create(recursive: true);
    final tmp = File('$_path.tmp');
    await tmp.writeAsString(jsonStr);
    await tmp.rename(_path);
  }

  /// Look up a carve-out entry by its lib/ path.
  Future<CarveOutEntry?> lookup(String libPath) async {
    final entries = await load();
    for (final entry in entries) {
      if (entry.path == libPath) return entry;
    }
    return null;
  }

  /// Add an entry (idempotent — skips if already present).
  Future<void> add(CarveOutEntry entry) async {
    final entries = await load();
    if (entries.any((e) => e.path == entry.path)) return;
    entries.add(entry);
    await save(entries);
  }

  /// Remove an entry by path. Returns true if removed, false if not found.
  Future<bool> remove(String libPath) async {
    final entries = await load();
    final before = entries.length;
    entries.removeWhere((e) => e.path == libPath);
    if (entries.length == before) return false;
    await save(entries);
    return true;
  }
}
