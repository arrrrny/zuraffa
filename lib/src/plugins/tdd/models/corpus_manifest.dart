/// `CorpusFeature` + `CorpusManifest` — the read-only input contract the
/// corpus harness consumes (spec 051-corpus-harness; the file shape is
/// pinned by spec 050-corpus-import's data-model: #627's import writes
/// `.zfa/manifests/corpus-manifest.json`).
///
/// The manifest's `features` order IS the driving order (FR-001): the
/// harness preserves file order verbatim and never re-sorts.
library;

/// Raised when the manifest JSON decodes to an unusable shape. The message
/// names the file and the recovery path (the misfire-stop contract,
/// FR-011).
class CorpusManifestException implements Exception {
  const CorpusManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One manifest row: a feature directory name plus its readiness mark.
class CorpusFeature {
  const CorpusFeature({required this.name, required this.ready, this.reason = ''});

  final String name;
  final bool ready;
  final String reason;
}

/// The ordered feature list the harness drives.
class CorpusManifest {
  const CorpusManifest({
    required this.features,
    this.sourceCorpus,
    this.importedAt,
  });

  final List<CorpusFeature> features;
  final String? sourceCorpus;
  final String? importedAt;

  /// Decode the raw [decoded] JSON value (the output of `jsonDecode`).
  /// Every malformed shape is a [CorpusManifestException] naming the file
  /// and the recovery path.
  static CorpusManifest fromJson(dynamic decoded) {
    Never malformed(String cause) => throw CorpusManifestException(
      'corrupted corpus-manifest.json ($cause). Recovery: repair it to '
      'valid manifest JSON — {"features": [{"name": <feature>, "ready": '
      '<bool>, "reason": <string>}, ...]} — or re-run the corpus import '
      '(zfa setup --specs / corpus import, #627) to regenerate it.',
    );

    if (decoded is! Map) {
      malformed('top-level value is not an object');
    }
    final map = decoded;
    final featuresRaw = map['features'];
    if (featuresRaw is! List) {
      malformed('"features" is not a list');
    }
    final features = <CorpusFeature>[];
    for (var i = 0; i < featuresRaw.length; i++) {
      final row = featuresRaw[i];
      if (row is! Map) {
        malformed('features[$i] is not an object');
      }
      final name = row['name'];
      if (name is! String || name.isEmpty) {
        malformed('features[$i] is missing a non-empty "name" string');
      }
      final ready = row['ready'];
      if (ready is! bool) {
        malformed('features[$i] "ready" is not a bool');
      }
      final reason = row['reason'];
      if (reason != null && reason is! String) {
        malformed('features[$i] "reason" is not a string');
      }
      features.add(
        CorpusFeature(name: name, ready: ready, reason: reason ?? ''),
      );
    }
    final sourceCorpus = map['sourceCorpus'];
    if (sourceCorpus != null && sourceCorpus is! String) {
      malformed('"sourceCorpus" is not a string');
    }
    final importedAt = map['importedAt'];
    if (importedAt != null && importedAt is! String) {
      malformed('"importedAt" is not a string');
    }
    return CorpusManifest(
      features: List.unmodifiable(features),
      sourceCorpus: sourceCorpus as String?,
      importedAt: importedAt as String?,
    );
  }
}
