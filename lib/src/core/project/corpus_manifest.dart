/// `CorpusManifest` — the ordered, machine-readable feature list emitted
/// by corpus import (`zfa corpus import` / `zfa setup --specs`, spec
/// 050-corpus-import) and consumed by batch driving (#628).
///
/// Stored at `.zfa/manifests/corpus-manifest.json` via
/// `ProjectPaths.manifestsDirectory` (the AGENTS.md canonical memory
/// layout). The manifest is the contract between import and batch
/// driving: features in deterministic lexicographic order, each carrying
/// its loop-readiness mark and reason.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_paths.dart';

/// One imported feature in the corpus manifest.
class CorpusFeature {
  final String name;
  final bool ready;
  final String reason;

  const CorpusFeature({
    required this.name,
    required this.ready,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'ready': ready,
    'reason': reason,
  };

  factory CorpusFeature.fromJson(Map<String, dynamic> json) => CorpusFeature(
    name: json['name'] as String,
    ready: json['ready'] as bool,
    reason: json['reason'] as String,
  );
}

/// The corpus manifest: every imported feature, in deterministic
/// lexicographic order, with the source corpus path and import time.
class CorpusManifest {
  final List<CorpusFeature> features;
  final String sourceCorpus;
  final String importedAt;

  CorpusManifest({
    required List<CorpusFeature> features,
    required this.sourceCorpus,
    required this.importedAt,
  }) : features = List.of(features)..sort((a, b) => a.name.compareTo(b.name));

  Map<String, dynamic> toJson() => {
    'source_corpus': sourceCorpus,
    'imported_at': importedAt,
    'features': features.map((f) => f.toJson()).toList(),
  };

  factory CorpusManifest.fromJson(Map<String, dynamic> json) => CorpusManifest(
    features: (json['features'] as List)
        .map((f) => CorpusFeature.fromJson(f as Map<String, dynamic>))
        .toList(),
    sourceCorpus: json['source_corpus'] as String,
    importedAt: json['imported_at'] as String,
  );

  /// Reads the manifest from `<projectRoot>/.zfa/manifests/
  /// corpus-manifest.json`.
  ///
  /// Returns `null` when no manifest has been written yet (never throws:
  /// a fresh app has simply not imported a corpus).
  static CorpusManifest? read(String projectRoot) {
    final file = _manifestFile(projectRoot);
    if (!file.existsSync()) return null;
    return CorpusManifest.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  /// Writes the manifest to `<projectRoot>/.zfa/manifests/
  /// corpus-manifest.json`, creating the directory when absent.
  ///
  /// The encoding is deterministic (fixed key order, indented JSON, sorted
  /// features), so identical re-imports produce byte-identical files
  /// except [importedAt] (SC-004). [dryRun] skips the write entirely.
  Future<void> write(String projectRoot, {bool dryRun = false}) async {
    if (dryRun) return;
    final file = _manifestFile(projectRoot);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(toJson()));
  }

  static File _manifestFile(String projectRoot) => File(
    p.join(
      ProjectPaths(projectRoot).manifestsDirectory,
      'corpus-manifest.json',
    ),
  );
}
