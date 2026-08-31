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

import 'dart:io';

import 'package:path/path.dart' as p;

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

  const CorpusImportResult({
    required this.features,
    required this.sourceCorpus,
  });

  /// Per-feature report lines (one line per feature, every applicable
  /// outcome flag on the line — never a single pigeonhole).
  List<String> get reportLines => throw UnimplementedError();

  /// The single summary line (counts + manifest path).
  String get summaryLine => throw UnimplementedError();
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
    return CorpusImportResult(
      features: const [],
      sourceCorpus: sourceDir.path,
    );
  }

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
}
