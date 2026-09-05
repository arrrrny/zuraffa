/// `zfa corpus` — the corpus onboarding command family (spec
/// 050-corpus-import, issue #627; epic #1017 CORPUS-WALK child #1015).
///
/// `corpus` hosts the corpus-level tooling as sibling subcommands:
/// `import` (spec 050) and `catalog` (CORE/SKIN classification).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/services/corpus_catalog.dart';
import '../cli/services/corpus_importer.dart';

class CorpusCommand extends Command<void> {
  CorpusCommand() {
    addSubcommand(CorpusImportCommand());
    addSubcommand(CorpusCatalogCommand());
  }

  @override
  String get name => 'corpus';

  @override
  String get description =>
      'Import an extracted spec corpus and catalog its features '
      '(CORE/SKIN classification). See specs/050-corpus-import and '
      'specs/076-corpus-walk for the contracts.';

  @override
  String get invocation => 'zfa corpus <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}

/// `zfa corpus import <source>` — import a spec corpus into the app's
/// `specs/` tree.
///
/// Copies every feature's `spec.md` verbatim, creates the per-feature
/// `tdd/` working directories, marks loop-readiness with the same
/// `SpecParser` verdict `zfa tdd plan` uses, and emits the corpus
/// manifest for batch driving (#628). Idempotent: re-imports skip
/// identical specs and report divergent ones (FR-003/FR-004). Exits 0
/// for a completed import — not-ready features are reported, not fatal
/// (FR-005); an invalid source is the only failure.
class CorpusImportCommand extends Command<void> {
  CorpusImportCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Report every outcome but write nothing (manifest included).',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help:
          'Replace divergent specs whose source content changed '
          '(default: keep the imported copy and report both hashes).',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'App root containing specs/. When omitted, the current working '
          'directory is used. Tests pass the temp fixture root here '
          'instead of mutating Directory.current.',
    );
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Import every feature spec from <source> into specs/ (verbatim), '
      'create per-feature tdd/ dirs, and emit the corpus manifest.';

  @override
  String get invocation => 'zfa corpus import <source> [--dry-run] [--force]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException(
        'Source corpus directory is required: zfa corpus import <source>',
      );
    }
    final source = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final force = argResults?['force'] as bool? ?? false;

    final result = await const CorpusImporter().import(
      source,
      projectRoot: projectRoot,
      force: force,
      dryRun: dryRun,
    );
    for (final line in result.reportLines) {
      print(line);
    }
    print(result.summaryLine);
  }
}

/// `zfa corpus catalog --target <name>` — catalog the target's specs and
/// classify each CORE/SKIN (epic #1017 CORPUS-WALK, child #1015).
///
/// Resolves the target's features from the corpus manifest (or
/// `--source` directly — explicit beats implicit), classifies each spec
/// CORE (engine seam) or SKIN (presentation seam) with the deterministic
/// signal classifier, and writes the COMMITTED catalog at
/// `corpus/catalogs/<target>.json`. Regeneration preserves committed
/// manual classifications for unchanged specs (the maintainer's edit
/// sticks) unless `--reclassify` is passed.
///
/// Machine contract: every feature prints `[corpus] <name> -> <CORE|
/// SKIN> [ (preserved)]`, and the invocation ends with
/// `corpus catalog: target=<t> source=<manifest|source> features=<n>
/// core=<c> skin=<s> result=ok`. Exit 0 ok; 2 runner/usage errors (no
/// manifest and no --source, missing spec, invalid target).
class CorpusCatalogCommand extends Command<void> {
  CorpusCatalogCommand() {
    argParser.addOption(
      'target',
      help:
          'The corpus target being walked (e.g. zik_zak) — names the '
          'catalog/ledger files under corpus/.',
    );
    argParser.addOption(
      'source',
      help:
          'A corpus root to walk directly (feature directories with '
          'spec.md) instead of the project\'s corpus manifest. Explicit '
          'beats implicit.',
    );
    argParser.addFlag(
      'reclassify',
      negatable: false,
      help:
          'Discard preserved manual classifications and recompute every '
          'verdict from the spec signals.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'App root containing specs/. When omitted, the current working '
          'directory is used (the corpus import\'s rule).',
    );
  }

  @override
  String get name => 'catalog';

  @override
  String get description =>
      'Catalog the target\'s specs and classify each CORE (engine seam) '
      'or SKIN (presentation seam) — the walk\'s input contract '
      '(epic #1017, child #1015).';

  @override
  String get invocation =>
      'zfa corpus catalog --target <name> [--source <dir>] [--reclassify]';

  static const _exitOk = 0;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    final target = argResults?['target'] as String?;
    if (target == null || target.isEmpty) {
      print(
        'zfa corpus catalog: --target is required (the corpus being '
        'cataloged, e.g. zik_zak — it names the catalog/ledger files).',
      );
      exitCode = _exitRunnerError;
      return;
    }
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final sourceFlag = argResults?['source'] as String?;
    final reclassify = argResults?['reclassify'] as bool? ?? false;

    try {
      final catalog = await buildCatalog(
        target: target,
        projectRoot: projectRoot,
        source: sourceFlag != null && sourceFlag.isNotEmpty
            ? p.absolute(sourceFlag)
            : null,
        reclassify: reclassify,
      );
      for (final f in catalog.features) {
        print(
          '[corpus] ${f.name} -> '
          '${f.classification == CorpusClass.core ? 'CORE' : 'SKIN'}'
          '${f.preserved ? ' (preserved)' : ''}'
          '${f.ready ? '' : ' [not-ready: ${f.reason.isEmpty ? 'no reason recorded' : f.reason}]'}',
        );
      }
      await CorpusCatalogStore(projectRoot).write(catalog);
      final core = catalog.features
          .where((f) => f.classification == CorpusClass.core)
          .length;
      print(
        'corpus catalog: target=${catalog.target} source=${catalog.source} '
        'features=${catalog.features.length} core=$core '
        'skin=${catalog.features.length - core} result=ok',
      );
      exitCode = _exitOk;
    } on CorpusCatalogException catch (e) {
      print('zfa corpus catalog: $e');
      exitCode = _exitRunnerError;
    }
  }
}
