/// `zfa corpus` — the corpus onboarding command family (spec
/// 050-corpus-import, issue #627).
///
/// `corpus` hosts the corpus-level tooling as sibling subcommands so
/// #628's batch driving (`run`/`status`/`audit`) slots in later at the
/// same level (plan.md Decision 2). This feature lands `import` only.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/services/corpus_importer.dart';

class CorpusCommand extends Command<void> {
  CorpusCommand() {
    addSubcommand(CorpusImportCommand());
  }

  @override
  String get name => 'corpus';

  @override
  String get description =>
      'Import and drive an extracted spec corpus (import). See '
      'specs/050-corpus-import/spec.md for the contract.';

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
