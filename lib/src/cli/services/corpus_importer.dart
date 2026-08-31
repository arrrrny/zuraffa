/// `CorpusImporter` — the shared corpus-import service (spec
/// 050-corpus-import, issue #627).
///
/// Both entry points — `zfa corpus import <source>` and
/// `zfa setup <name> --specs <dir>` — delegate here so their semantics can
/// never drift (plan.md Decision 1). The importer copies each source
/// feature's `spec.md` verbatim into the app's `specs/<feature>/`, creates
/// the per-feature `tdd/` working directory (never touching existing
/// contents), marks loop-readiness with the exact `SpecParser` verdict
/// `zfa tdd plan` uses, and emits the deterministic corpus manifest batch
/// driving (#628) consumes.
///
/// Idempotent and non-destructive (FR-003/FR-004): identical specs are
/// skipped, divergent ones kept and reported with both sha256 hashes
/// unless `--force` is passed, and existing `tdd/` evidence is never
/// read or written.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/project/corpus_manifest.dart';
import '../../plugins/tdd/services/spec_parser.dart';
import '../../utils/file_utils.dart';

/// Per-feature copy decision.
enum ImportOutcome {
  /// Target spec was absent and has been copied.
  imported,

  /// An identical copy was already present; nothing written.
  skipped,

  /// Source differs from the imported copy; target kept (see hashes).
  divergent,
}

/// One feature's import result, in manifest order.
class FeatureImportResult {
  final String name;
  final ImportOutcome outcome;

  /// Loop-readiness mark — the `SpecParser` verdict for this spec.
  final bool ready;

  /// One-line reason when [ready] is false (empty otherwise).
  final String reason;

  /// Source carried speckit-era foreign artifacts (reported, ignored).
  final bool hasForeignArtifacts;

  /// Names of the ignored foreign artifacts (e.g. `checklists/`).
  final List<String> ignoredArtifacts;

  /// sha256 hex of the source spec when [outcome] is
  /// [ImportOutcome.divergent].
  final String? sourceHash;

  /// sha256 hex of the target spec when [outcome] is
  /// [ImportOutcome.divergent].
  final String? targetHash;

  const FeatureImportResult({
    required this.name,
    required this.outcome,
    required this.ready,
    required this.reason,
    this.hasForeignArtifacts = false,
    this.ignoredArtifacts = const [],
    this.sourceHash,
    this.targetHash,
  });
}

/// The whole corpus-import result: per-feature outcomes plus the report
/// lines the commands print (contracts/corpus-import.md).
class CorpusImportResult {
  /// Per-feature results in manifest order (lexicographic).
  final List<FeatureImportResult> features;

  /// Absolute path of the imported source corpus.
  final String sourceCorpus;

  /// The app root the corpus was imported into.
  final String projectRoot;

  /// Whether this run was a dry run (every report line is prefixed).
  final bool dryRun;

  const CorpusImportResult({
    required this.features,
    required this.sourceCorpus,
    required this.projectRoot,
    this.dryRun = false,
  });

  /// Per-feature report lines (one line per feature, every applicable
  /// outcome flag on the line — never a single pigeonhole).
  List<String> get reportLines => [
    for (final f in features) '$_prefix${_lineFor(f)}',
  ];

  /// The single summary line (counts + manifest path).
  String get summaryLine {
    final imported = features
        .where((f) => f.outcome == ImportOutcome.imported)
        .length;
    final skipped = features
        .where((f) => f.outcome == ImportOutcome.skipped)
        .length;
    final divergent = features
        .where((f) => f.outcome == ImportOutcome.divergent)
        .length;
    final notReady = features.where((f) => !f.ready).length;
    return '$_prefix'
        'corpus import: ${features.length} features — '
        '$imported imported, $skipped skipped, $divergent divergent, '
        '$notReady not-ready (manifest: $_manifestPath)';
  }

  String get _prefix => dryRun ? '[dry-run] ' : '';

  String get _manifestPath =>
      p.join(projectRoot, '.zfa', 'manifests', 'corpus-manifest.json');

  String _lineFor(FeatureImportResult f) {
    final flags = <String>[];
    switch (f.outcome) {
      case ImportOutcome.imported:
        flags.add('imported');
      case ImportOutcome.skipped:
        flags.add('skipped');
      case ImportOutcome.divergent:
        flags.add(
          'divergent (source sha256:${f.sourceHash}, '
          'target sha256:${f.targetHash})',
        );
    }
    if (f.hasForeignArtifacts) {
      flags.add('foreign-artifacts-ignored (${f.ignoredArtifacts.join(', ')})');
    }
    if (!f.ready) {
      flags.add('not-ready (${f.reason})');
    }
    return '${f.name}: ${flags.join(' ')}';
  }
}

/// The shared corpus-import service.
class CorpusImporter {
  const CorpusImporter();

  /// Imports the corpus at [source] into `<projectRoot>/specs/`.
  ///
  /// [projectRoot] is the app root (the directory holding `specs/`).
  /// [force] replaces divergent specs instead of keeping them (FR-004).
  /// [dryRun] reports everything but writes nothing (FR-003).
  Future<CorpusImportResult> import(
    String source, {
    required String projectRoot,
    bool force = false,
    bool dryRun = false,
  }) async {
    final sourceDir = _validateSource(source);
    final featureNames = _scanFeatures(sourceDir);

    final results = <FeatureImportResult>[];
    for (final name in featureNames) {
      final sourceSpec = File(p.join(sourceDir.path, name, 'spec.md'));
      final targetSpec = File(p.join(projectRoot, 'specs', name, 'spec.md'));
      final content = sourceSpec.readAsStringSync();
      final readiness = _readiness(name, content);
      final foreign = _foreignArtifacts(
        Directory(p.join(sourceDir.path, name)),
      );

      // sha256-aware copy decision (FR-001/FR-003/FR-004): absent ->
      // imported; identical -> skipped; different -> divergent unless
      // --force (U8/U9).
      ImportOutcome outcome;
      String? sourceHash;
      String? targetHash;
      if (!targetSpec.existsSync()) {
        outcome = ImportOutcome.imported;
        await FileUtils.writeFile(
          targetSpec.path,
          content,
          'spec',
          force: true,
          dryRun: dryRun,
        );
      } else {
        sourceHash = _sha256(content);
        targetHash = _sha256(targetSpec.readAsStringSync());
        if (sourceHash == targetHash) {
          outcome = ImportOutcome.skipped;
        } else if (force) {
          // --force: the source content replaces the divergent copy
          // (U9, FR-004 — explicit opt-in).
          outcome = ImportOutcome.imported;
          await FileUtils.writeFile(
            targetSpec.path,
            content,
            'spec',
            force: true,
            dryRun: dryRun,
          );
        } else {
          // Divergent: the imported copy is kept; both hashes travel in
          // the result and the report line (FR-004).
          outcome = ImportOutcome.divergent;
        }
      }
      // Per-feature tdd/ working directory (U10): created when absent,
      // never touching existing contents (U11/FR-003).
      final targetTdd = Directory(p.join(projectRoot, 'specs', name, 'tdd'));
      if (!targetTdd.existsSync() && !dryRun) {
        await targetTdd.create(recursive: true);
      }
      results.add(
        FeatureImportResult(
          name: name,
          outcome: outcome,
          ready: readiness.ready,
          reason: readiness.reason,
          hasForeignArtifacts: foreign.isNotEmpty,
          ignoredArtifacts: foreign,
          sourceHash: sourceHash,
          targetHash: targetHash,
        ),
      );
    }
    // The corpus manifest — the #628 batch-driving contract (A1/FR-002):
    // every imported feature, in deterministic order, with its readiness
    // mark. Regenerated on every import so it always reflects the current
    // corpus state; byte-stable except imported_at (SC-004).
    final manifest = CorpusManifest(
      features: [
        for (final f in results)
          CorpusFeature(name: f.name, ready: f.ready, reason: f.reason),
      ],
      sourceCorpus: sourceDir.path,
      importedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await manifest.write(projectRoot, dryRun: dryRun);

    return CorpusImportResult(
      features: results,
      sourceCorpus: sourceDir.path,
      projectRoot: p.absolute(projectRoot),
      dryRun: dryRun,
    );
  }

  /// sha256 hex of [content] — the divergence-reporting currency
  /// (FR-004), same hashing `TreeSnapshot` uses for tree fingerprints.
  static String _sha256(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  /// Validates that [source] is a corpus root and returns it as a
  /// [Directory] (U5): it must exist, be a directory, not be a single
  /// feature directory (spec.md directly inside), and hold at least one
  /// feature spec.
  Directory _validateSource(String source) {
    final sourceDir = Directory(p.absolute(source));
    if (!sourceDir.existsSync()) {
      throw StateError(
        'zfa corpus import: source corpus not found: ${sourceDir.path}',
      );
    }
    if (FileSystemEntity.typeSync(sourceDir.path) ==
        FileSystemEntityType.file) {
      throw StateError(
        'zfa corpus import: source is a file, not a corpus root: '
        '${sourceDir.path}',
      );
    }
    final directSpec = File(p.join(sourceDir.path, 'spec.md'));
    if (directSpec.existsSync()) {
      throw StateError(
        'zfa corpus import: source looks like a single feature directory '
        '(it contains spec.md directly), not a corpus root: '
        '${sourceDir.path}. Point at the corpus root — the directory that '
        'holds the feature directories.',
      );
    }
    return sourceDir;
  }

  /// Scans the corpus root for feature directories — subdirectories that
  /// carry a `spec.md` (the source-corpus contract: a directory of feature
  /// directories, each with at least spec.md). Files, hidden directories,
  /// and directories without a spec are not features. Returned in
  /// deterministic lexicographic order (FR-002).
  List<String> _scanFeatures(Directory sourceDir) {
    final names =
        sourceDir
            .listSync()
            .whereType<Directory>()
            .map((d) {
              return p.basename(d.path);
            })
            .where((name) {
              if (name.startsWith('.')) return false;
              return File(p.join(sourceDir.path, name, 'spec.md')).existsSync();
            })
            .toList()
          ..sort();
    if (names.isEmpty) {
      throw StateError(
        'zfa corpus import: no feature specs found in ${sourceDir.path} '
        '(expected a directory of feature directories, each containing '
        'spec.md)',
      );
    }
    return names;
  }

  /// Loop-readiness (U12, FR-006): the exact `SpecParser` entry point
  /// `zfa tdd plan` uses — never a second parser, never regex sniffing
  /// (plan.md Decision 4). A parse failure becomes the not-ready mark
  /// with the parser's reason (compacted to one line); a parse success
  /// becomes the ready mark.
  _Readiness _readiness(String feature, String specMd) {
    try {
      const SpecParser().parse(feature, specMd);
      return const _Readiness(true, '');
    } on StateError catch (e) {
      return _Readiness(false, _compactReason(e.message));
    }
  }

  /// Compacts the parser's failure message to the one-line reason the
  /// manifest carries. The canonical no-acceptance-scenarios refusal maps
  /// to the documented phrase; any other parser failure keeps its first
  /// sentence.
  static String _compactReason(String message) {
    if (message.contains('contains no acceptance scenarios')) {
      return 'no acceptance scenarios';
    }
    final firstSentence = message.split('. ').first;
    return firstSentence.endsWith('.') ? firstSentence : '$firstSentence.';
  }

  /// Foreign-artifact detection (U13, FR-007): every entry in a source
  /// feature directory other than `spec.md` is a speckit-era artifact the
  /// import ignores — reported by name, never copied, converted, or
  /// deleted (format conversion is #617's contract, not ours).
  List<String> _foreignArtifacts(Directory sourceFeature) {
    return sourceFeature
        .listSync()
        .map((e) => p.basename(e.path))
        .where((name) => name != 'spec.md')
        .toList()
      ..sort();
  }
}

class _Readiness {
  final bool ready;
  final String reason;
  const _Readiness(this.ready, this.reason);
}
