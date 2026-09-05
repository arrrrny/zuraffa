/// `CorpusCatalog` — the corpus-walk's input contract (epic #1017
/// CORPUS-WALK, child "Catalog ZikZak specs; classify CORE/SKIN").
///
/// The catalog resolves a target's features (the corpus manifest written
/// by `zfa corpus import`, or a `--source` corpus root directly),
/// classifies each spec CORE (engine seam) or SKIN (presentation seam),
/// and writes the COMMITTED catalog at `corpus/catalogs/<target>.json`.
///
/// Committed, so the classification is reviewable: regeneration preserves
/// a committed manual classification whose spec hash is unchanged
/// (the maintainer's edit sticks — the same preservation philosophy the
/// import applies to `tdd/` evidence), and `--reclassify` discards the
/// edits and recomputes.
///
/// The classifier is deterministic and documented (see
/// `CorpusClassifier`): signal scoring over the feature name + spec
/// content, ties resolved CORE (engine-first — the engine must exist
/// before a skin can wrap it).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../plugins/tdd/models/corpus_manifest.dart';
import '../../plugins/tdd/services/corpus_manifest_store.dart';
import '../../plugins/tdd/services/spec_parser.dart';

/// Which layer of the engine/skin split a spec belongs to.
enum CorpusClass { core, skin }

/// One cataloged feature: name, classification, readiness, spec hash.
class CatalogFeature {
  const CatalogFeature({
    required this.name,
    required this.classification,
    required this.ready,
    required this.reason,
    required this.specSha256,
    this.preserved = false,
  });

  final String name;
  final CorpusClass classification;
  final bool ready;
  final String reason;

  /// sha256 hex of `specs/<name>/spec.md` — the content hash the ledger
  /// renews and the drift gates compare.
  final String specSha256;

  /// The classification came from the committed catalog (a preserved
  /// manual edit), not from the classifier.
  final bool preserved;

  Map<String, dynamic> toJson() => {
    'name': name,
    'classification': classification == CorpusClass.core ? 'CORE' : 'SKIN',
    'ready': ready,
    'reason': reason,
    'spec_sha256': specSha256,
  };

  static CatalogFeature fromJson(Map<String, dynamic> json) {
    final classificationRaw = json['classification'] as String;
    return CatalogFeature(
      name: json['name'] as String,
      classification: classificationRaw == 'SKIN'
          ? CorpusClass.skin
          : CorpusClass.core,
      ready: json['ready'] as bool,
      reason: (json['reason'] as String?) ?? '',
      specSha256: json['spec_sha256'] as String,
    );
  }
}

/// The committed catalog for one walk target.
class CorpusCatalog {
  const CorpusCatalog({
    required this.target,
    required this.source,
    required this.generatedAt,
    required this.features,
  });

  final String target;

  /// `manifest` (features resolved from the corpus manifest) or `source`
  /// (features walked from a `--source` corpus root).
  final String source;

  final String generatedAt;
  final List<CatalogFeature> features;

  Map<String, dynamic> toJson() => {
    'target': target,
    'generated_at': generatedAt,
    'source': source,
    'features': [for (final f in features) f.toJson()],
  };
}

/// Raised for every catalog-level misfire (missing manifest, missing
/// spec, corrupt JSON, invalid target). The message always names the
/// recovery path with a `--> fix:` hint.
class CorpusCatalogException implements Exception {
  const CorpusCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The deterministic CORE/SKIN classifier (epic #1017 child #1015).
///
/// Signals are counted with case-insensitive word-boundary matches over
/// the feature name + `spec.md` content. Skin signals name the
/// presentation seam (views, routes, adaptive layouts, platforms); core
/// signals name the engine seam (entities, mocks, repositories, DI,
/// use cases). Skin wins only on a STRICT majority — a tie classifies
/// CORE (engine-first: the engine contract exists before a skin wraps
/// it, so ambiguity resolves toward the layer that owns the data).
class CorpusClassifier {
  const CorpusClassifier();

  static const List<String> _skinSignals = [
    'view',
    'views',
    'page',
    'pages',
    'screen',
    'screens',
    'route',
    'routes',
    'router',
    'navigation',
    'navigate',
    'navigates',
    'widget',
    'widgets',
    'layout',
    'layouts',
    'adaptive',
    'platform',
    'platforms',
    'theme',
    'ui',
    'button',
    'buttons',
    'form',
    'forms',
    'dialog',
    'dialogs',
    'animation',
    'animations',
    'scaffold',
    'skin',
  ];

  static const List<String> _coreSignals = [
    'entity',
    'entities',
    'usecase',
    'usecases',
    'mock',
    'mocks',
    'repository',
    'repositories',
    'datasource',
    'datasources',
    'service',
    'services',
    'domain',
    'binding',
    'bindings',
    'injection',
    'state',
    'contract',
    'contracts',
    'logic',
    'model',
    'models',
    'policy',
    'validation',
    'session',
    'cache',
    'sync',
    'engine',
  ];

  CorpusClass classify(String featureName, String specMd) {
    final text = '$featureName\n$specMd';
    final skin = _count(text, _skinSignals);
    final core = _count(text, _coreSignals);
    return skin > core ? CorpusClass.skin : CorpusClass.core;
  }

  static int _count(String text, List<String> signals) {
    var total = 0;
    for (final signal in signals) {
      final pattern = RegExp(
        '\\b${RegExp.escape(signal)}\\b',
        caseSensitive: false,
      );
      total += pattern.allMatches(text).length;
    }
    return total;
  }
}

/// Builds and reads the committed catalogs (`corpus/catalogs/`).
class CorpusCatalogStore {
  const CorpusCatalogStore(this.projectRoot);

  final String projectRoot;

  String get catalogsDirectory => p.join(projectRoot, 'corpus', 'catalogs');

  String catalogPath(String target) =>
      p.join(catalogsDirectory, '$target.json');

  /// Reads the committed catalog for [target]; `null` when none exists.
  ///
  /// Throws [CorpusCatalogException] on a corrupt file (naming the
  /// recovery path — regenerate with `zfa corpus catalog --target`).
  CorpusCatalog? read(String target) {
    final file = File(catalogPath(target));
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw const FormatException('top-level value is not an object');
      }
      final rows = decoded['features'];
      if (rows is! List) {
        throw const FormatException('"features" is not a list');
      }
      return CorpusCatalog(
        target: decoded['target'] as String,
        source: (decoded['source'] as String?) ?? 'manifest',
        generatedAt: (decoded['generated_at'] as String?) ?? '',
        features: [
          for (final row in rows)
            CatalogFeature.fromJson((row as Map).cast<String, dynamic>()),
        ],
      );
    } on FormatException catch (e) {
      throw CorpusCatalogException(
        'corrupted catalog for target "$target" (${catalogPath(target)}): '
        '$e --> fix: regenerate it with '
        '`zfa corpus catalog --target $target` (committed manual '
        'classifications for unchanged specs are preserved).',
      );
    } on TypeError catch (e) {
      throw CorpusCatalogException(
        'corrupted catalog for target "$target" (${catalogPath(target)}): '
        '$e --> fix: regenerate it with '
        '`zfa corpus catalog --target $target`.',
      );
    }
  }

  /// Writes the catalog deterministically (fixed key order, sorted
  /// features) so identical inputs produce byte-identical files except
  /// `generated_at`.
  Future<void> write(CorpusCatalog catalog) async {
    final file = File(catalogPath(catalog.target));
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(catalog.toJson()));
  }
}

/// Validates a target name (it becomes a filename under
/// `corpus/catalogs/`): lowercase letters, digits, dashes, underscores.
void validateTargetName(String target) {
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(target)) {
    throw CorpusCatalogException(
      'invalid target name "$target" — the target names the corpus being '
      'walked (e.g. zik_zak) and becomes the catalog/ledger filename; '
      'use lowercase letters, digits, dashes, and underscores.',
    );
  }
}

/// Builds the catalog for [target] from the manifest (or [source] when
/// given — explicit beats implicit), preserving committed manual
/// classifications for unchanged specs unless [reclassify].
Future<CorpusCatalog> buildCatalog({
  required String target,
  required String projectRoot,
  String? source,
  bool reclassify = false,
}) async {
  validateTargetName(target);
  final store = CorpusCatalogStore(projectRoot);
  final existing = reclassify ? null : store.read(target);
  final preservedByName = <String, CatalogFeature>{
    if (existing != null)
      for (final f in existing.features) f.name: f,
  };

  final rows = source == null
      ? await _rowsFromManifest(projectRoot)
      : _rowsFromSource(source);

  final classifier = const CorpusClassifier();
  final features = <CatalogFeature>[];
  for (final row in rows) {
    // The spec the classification + hash read: the imported spec under
    // the project (manifest mode) or the source corpus spec (--source).
    final specFile = File(
      source == null
          ? p.join(projectRoot, 'specs', row.name, 'spec.md')
          : p.join(source, row.name, 'spec.md'),
    );
    if (!specFile.existsSync()) {
      throw CorpusCatalogException(
        'spec for feature "${row.name}" is missing (${specFile.path}) — '
        'the manifest lists it but the spec file does not exist. '
        '--> fix: re-import the corpus (zfa corpus import <source>) or '
        'restore specs/${row.name}/spec.md, then re-run the catalog.',
      );
    }
    final specMd = specFile.readAsStringSync();
    final specSha256 = sha256.convert(specFile.readAsBytesSync()).toString();

    // Preservation (the committed edit sticks): same feature, same spec
    // hash, an explicit committed classification.
    final preserved = preservedByName[row.name];
    final preservedApplies =
        preserved != null && preserved.specSha256 == specSha256;
    final classification = preservedApplies
        ? preserved.classification
        : classifier.classify(row.name, specMd);

    features.add(
      CatalogFeature(
        name: row.name,
        classification: classification,
        ready: row.ready,
        reason: row.reason,
        specSha256: specSha256,
        preserved: preservedApplies,
      ),
    );
  }
  features.sort((a, b) => a.name.compareTo(b.name));

  return CorpusCatalog(
    target: target,
    source: source == null ? 'manifest' : 'source',
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    features: features,
  );
}

({String name, bool ready, String reason}) _row(
  String name,
  bool ready,
  String reason,
) => (name: name, ready: ready, reason: reason);

Future<List<({String name, bool ready, String reason})>> _rowsFromManifest(
  String projectRoot,
) async {
  final store = CorpusManifestStore(projectRoot);
  try {
    final manifest = await store.readManifest();
    return [for (final f in manifest.features) _row(f.name, f.ready, f.reason)];
  } on CorpusManifestMissingException catch (e) {
    throw CorpusCatalogException(
      '${e.message} The catalog resolves the target\'s features from the '
      'manifest. --> fix: run `zfa corpus import <source>` first, or pass '
      'the corpus root directly via --source.',
    );
  } on CorpusManifestException catch (e) {
    throw CorpusCatalogException(
      '$e --> fix: repair the manifest or re-run the corpus import, then '
      're-run the catalog.',
    );
  }
}

List<({String name, bool ready, String reason})> _rowsFromSource(
  String source,
) {
  final sourceDir = Directory(p.absolute(source));
  if (!sourceDir.existsSync()) {
    throw CorpusCatalogException(
      'source corpus not found: ${sourceDir.path} — point --source at the '
      'corpus root (the directory holding the feature directories).',
    );
  }
  final names =
      sourceDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .where((name) {
            if (name.startsWith('.')) return false;
            return File(p.join(sourceDir.path, name, 'spec.md')).existsSync();
          })
          .toList()
        ..sort();
  if (names.isEmpty) {
    throw CorpusCatalogException(
      'no feature specs found in ${sourceDir.path} (expected a directory '
      'of feature directories, each containing spec.md).',
    );
  }
  // Readiness from the same parser verdict `zfa tdd plan` and the import
  // use — never a second parser (plan.md Decision 4).
  return [
    for (final name in names)
      () {
        final specMd = File(
          p.join(sourceDir.path, name, 'spec.md'),
        ).readAsStringSync();
        try {
          const SpecParser().parse(name, specMd);
          return _row(name, true, '');
        } on StateError catch (e) {
          return _row(name, false, _compactReason(e.message));
        }
      }(),
  ];
}

String _compactReason(String message) {
  if (message.contains('contains no acceptance scenarios')) {
    return 'no acceptance scenarios';
  }
  final firstSentence = message.split('. ').first;
  return firstSentence.endsWith('.') ? firstSentence : '$firstSentence.';
}
