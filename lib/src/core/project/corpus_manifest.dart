/// Corpus manifest model (spec 050-corpus-import, consumed by 051).
///
/// Reads `.zfa/manifests/corpus-manifest.json` — the ordered feature list
/// produced by `zfa corpus import`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A single feature in the corpus manifest.
class CorpusManifestFeature {
  const CorpusManifestFeature({
    required this.name,
    required this.ready,
    this.reason = '',
  });

  factory CorpusManifestFeature.fromJson(Map<String, dynamic> json) =>
      CorpusManifestFeature(
        name: json['name'] as String,
        ready: json['ready'] as bool? ?? false,
        reason: json['reason'] as String? ?? '',
      );

  final String name;
  final bool ready;
  final String reason;

  Map<String, dynamic> toJson() => {
    'name': name,
    'ready': ready,
    'reason': reason,
  };
}

/// The corpus manifest — ordered features with readiness marks.
class CorpusManifest {
  const CorpusManifest({
    required this.features,
    this.sourceCorpus = '',
    this.importedAt = '',
  });

  factory CorpusManifest.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'] as List<dynamic>? ?? [];
    final features = featuresRaw
        .map((f) => CorpusManifestFeature.fromJson(f as Map<String, dynamic>))
        .toList();
    return CorpusManifest(
      features: features,
      sourceCorpus: json['source_corpus'] as String? ?? '',
      importedAt: json['imported_at'] as String? ?? '',
    );
  }

  final List<CorpusManifestFeature> features;
  final String sourceCorpus;
  final String importedAt;

  /// Read the manifest from the project root, or null if absent.
  static Future<CorpusManifest?> read(String projectRoot) async {
    final path = p.join(
      projectRoot,
      '.zfa',
      'manifests',
      'corpus-manifest.json',
    );
    final file = File(path);
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return CorpusManifest.fromJson(decoded);
  }
}
