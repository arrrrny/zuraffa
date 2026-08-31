/// `CorpusManifestStore` — reads the corpus harness's input contracts
/// (spec 051-corpus-harness): the corpus manifest (#627's file), the
/// carve-out manifest, and the maintainer waivers. Owns the `.zfa/`
/// path constants. Read-only: the harness never writes these files.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/corpus_manifest.dart';
import '../models/corpus_progress.dart';

class CorpusManifestStore {
  CorpusManifestStore(this.projectRoot);

  /// The driven app's project root.
  final String projectRoot;

  /// Corpus input/state paths (spec 051 contracts; the manifest path is
  /// the 050-corpus-import contract).
  String get manifestPath =>
      p.join(projectRoot, '.zfa', 'manifests', 'corpus-manifest.json');
  String get carveOutPath =>
      p.join(projectRoot, '.zfa', 'manifests', 'corpus-carveout.json');
  String get waiversPath =>
      p.join(projectRoot, '.zfa', 'corpus', 'waivers.json');
  String get provenanceDir => p.join(projectRoot, '.zfa', 'provenance');
  String get corpusDir => p.join(projectRoot, '.zfa', 'corpus');
  String get progressPath => p.join(corpusDir, 'progress.json');
  String get ledgerPath => p.join(corpusDir, 'gap-ledger.json');
  String get auditReportPath => p.join(corpusDir, 'audit-report.json');

  /// Read and decode the corpus manifest.
  ///
  /// Throws [CorpusManifestMissingException] when the file is absent
  /// (the distinct no-manifest outcome) and [CorpusCorruptException] /
  /// [CorpusManifestException] when it cannot be decoded.
  Future<CorpusManifest> readManifest() async {
    final file = File(manifestPath);
    if (!await file.exists()) {
      throw CorpusManifestMissingException(
        'no corpus manifest at $manifestPath — run the corpus import '
        '(zfa setup --specs <dir> / corpus import, #627) to emit one '
        'before driving the corpus.',
      );
    }
    final dynamic decoded = _decodeStrictly(
      await file.readAsString(),
      manifestPath,
    );
    return CorpusManifest.fromJson(decoded);
  }

  /// Read the carve-out manifest entries (empty when the file is absent).
  Future<List<CarveOutEntry>> readCarveOut() async {
    final file = File(carveOutPath);
    if (!await file.exists()) return const [];
    final decoded = _decodeStrictly(await file.readAsString(), carveOutPath);
    if (decoded is! Map || decoded['carveouts'] is! List) {
      throw _corrupt(carveOutPath, '"carveouts" is not a list');
    }
    final entries = <CarveOutEntry>[];
    final rows = decoded['carveouts'] as List;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map ||
          row['path'] is! String ||
          (row['path'] as String).isEmpty ||
          row['reason'] is! String) {
        throw _corrupt(
          carveOutPath,
          'carveouts[$i] must carry non-empty "path" and "reason" strings',
        );
      }
      entries.add(
        CarveOutEntry(path: row['path'] as String, reason: row['reason'] as String),
      );
    }
    return entries;
  }

  /// Read the maintainer waivers (empty when the file is absent).
  Future<List<CorpusWaiver>> readWaivers() async {
    final file = File(waiversPath);
    if (!await file.exists()) return const [];
    final decoded = _decodeStrictly(await file.readAsString(), waiversPath);
    if (decoded is! List) {
      throw _corrupt(waiversPath, 'top-level value is not a list');
    }
    final waivers = <CorpusWaiver>[];
    for (var i = 0; i < decoded.length; i++) {
      final row = decoded[i];
      if (row is! Map ||
          row['feature'] is! String ||
          row['gate'] is! String ||
          row['reason'] is! String ||
          row['actor'] is! String ||
          row['at'] is! String) {
        throw _corrupt(
          waiversPath,
          'waivers[$i] must carry feature/gate/reason/actor/at strings',
        );
      }
      final map = Map<String, dynamic>.from(row);
      waivers.add(CorpusWaiver.fromJson(map));
    }
    return waivers;
  }

  /// Decode [raw] as JSON, mapping a parse failure to the corrupt-state
  /// exception naming [path].
  static dynamic _decodeStrictly(String raw, String path) {
    try {
      return jsonDecode(raw);
    } on FormatException catch (e) {
      throw _corrupt(path, 'invalid JSON: ${e.message}');
    }
  }

  static CorpusCorruptException _corrupt(String path, String cause) =>
      CorpusCorruptException(
        'corrupted $path ($cause). Recovery: repair it to the documented '
        'shape or delete it (absent means empty, never corrupt).',
      );
}
