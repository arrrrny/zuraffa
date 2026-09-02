/// `zfa tdd corpus differential` — the generator behavioral
/// differential gate (bug #805, vision slice v0).
///
/// Runs the shipped regression corpus against TWO generator refs and
/// compares the result vectors: exit codes, outcome classes (complete
/// / failed / hang), machine tokens, dart-test pass/fail counts, and
/// the artifact inventory — behavior, never bytes.
///
/// Each ref is materialized as a detached git worktree and its
/// dependencies resolved; each entry's `project/` scaffold is copied
/// into a fresh scratch dir per (entry, ref) and driven there. The
/// gate is honest by construction: a killed step records `hang` (the
/// #744 class), a diverging vector fails the gate naming the exact
/// entry and step pair (e.g. `u2-flow: hang vs complete`), and every
/// invocation ends with the machine summary line
/// `differential: entries=<n> compared=<n> differing=<n> errors=<n>
/// from=<ref> to=<ref> result=<match|differ|runner-error>`.
///
/// Exit codes: 0 vectors match (no behavioral divergence), 1 a
/// behavioral divergence exists, 2 runner-error (bad ref, missing or
/// corrupt corpus, setup failure).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../models/differential_vector.dart';
import '../services/differential_corpus.dart';
import '../services/differential_ref_runner.dart';
import '../tdd_plugin.dart';

class CorpusDifferentialCommand extends Command<void> {
  CorpusDifferentialCommand(
    this.plugin, {
    DifferentialSpawner? spawner,
    DifferentialGitRunner? gitRunner,
    Directory? scratchRoot,
  }) : _spawnerOverride = spawner,
       _gitRunnerOverride = gitRunner,
       _scratchRootOverride = scratchRoot {
    argParser.addOption(
      'from',
      help:
          'The baseline generator git ref (e.g. origin/master, a tag, a '
          'sha) to compare against. Required.',
    );
    argParser.addOption(
      'to',
      help: 'The generator git ref under test. Defaults to HEAD.',
      defaultsTo: 'HEAD',
    );
    argParser.addOption(
      'corpus',
      help:
          'The differential corpus directory (each entry: entry.json + a '
          'project/ scaffold). Defaults to <project-root>/corpus.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'The generator repo root the refs resolve against. When omitted, '
          'the current working directory is used.',
    );
    argParser.addOption(
      'budget',
      help:
          'Per-step wall-clock budget in seconds (default 300). A step '
          'that outlives it is killed and records the hang outcome — the '
          '#744 regression class.',
      defaultsTo: '300',
    );
    argParser.addFlag(
      'keep-scratch',
      help:
          'Keep the per-entry scratch dirs after the run (worktrees are '
          'always removed). For debugging a divergence.',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  final DifferentialSpawner? _spawnerOverride;
  final DifferentialGitRunner? _gitRunnerOverride;
  final Directory? _scratchRootOverride;

  @override
  String get name => 'differential';

  @override
  String get description =>
      'Run the regression corpus against two generator refs and fail on '
      'any behavioral divergence (bug #805).';

  @override
  String get invocation =>
      'zfa tdd corpus differential --from <ref> [--to HEAD] '
      '[--corpus <dir>] [--budget <seconds>]';

  static const _exitMatch = 0;
  static const _exitDiffer = 1;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();
    final from = argResults?['from'] as String?;
    final to = argResults?['to'] as String? ?? 'HEAD';
    final keepScratch = argResults?['keep-scratch'] as bool? ?? false;

    void summary({
      required int entries,
      required int compared,
      required int differing,
      required int errors,
      required String result,
    }) {
      print(
        'differential: entries=$entries compared=$compared '
        'differing=$differing errors=$errors from=${from ?? '-'} to=$to '
        'result=$result',
      );
    }

    // The --from ref is the anchor of the whole comparison.
    if (from == null || from.isEmpty) {
      print(
        'zfa tdd corpus differential: --from is required (the baseline '
        'generator ref to compare against)',
      );
      summary(
        entries: 0,
        compared: 0,
        differing: 0,
        errors: 0,
        result: 'runner-error',
      );
      exitCode = _exitRunnerError;
      return;
    }

    final budgetSeconds = int.tryParse(argResults?['budget'] as String? ?? '');
    if (budgetSeconds == null || budgetSeconds <= 0) {
      print(
        'zfa tdd corpus differential: invalid --budget '
        '"${argResults?['budget']}": pass a positive number of seconds',
      );
      summary(
        entries: 0,
        compared: 0,
        differing: 0,
        errors: 0,
        result: 'runner-error',
      );
      exitCode = _exitRunnerError;
      return;
    }

    // The corpus (missing/empty/corrupt are distinct runner-errors).
    final corpusDir = (argResults?['corpus'] as String?)?.isNotEmpty == true
        ? argResults!['corpus'] as String
        : p.join(projectRoot, 'corpus');
    final List<DifferentialEntry> entries;
    try {
      entries = await DifferentialCorpus.load(corpusDir);
    } on DifferentialCorpusException catch (e) {
      print('zfa tdd corpus differential: ${e.message}');
      summary(
        entries: 0,
        compared: 0,
        differing: 0,
        errors: 0,
        result: 'runner-error',
      );
      exitCode = _exitRunnerError;
      return;
    }

    final runner = DifferentialRefRunner(
      spawner: _spawnerOverride,
      gitRunner: _gitRunnerOverride,
      budget: Duration(seconds: budgetSeconds),
    );

    // Ref resolution + worktree materialization + setup.
    final scratchBase =
        _scratchRootOverride ??
        await Directory.systemTemp.createTemp('zfa-differential-');
    final worktrees = <String, String>{};
    try {
      final String fromSha;
      final String toSha;
      try {
        fromSha = await runner.resolveRef(from, repoRoot: projectRoot);
        toSha = await runner.resolveRef(to, repoRoot: projectRoot);
      } on DifferentialRefException catch (e) {
        print('zfa tdd corpus differential: ${e.message}');
        summary(
          entries: entries.length,
          compared: 0,
          differing: 0,
          errors: 0,
          result: 'runner-error',
        );
        exitCode = _exitRunnerError;
        return;
      }

      print(
        'zfa tdd corpus differential: ${entries.length} entry(s) from '
        '$from (${_short(fromSha)}) to $to (${_short(toSha)})',
      );

      try {
        worktrees['from'] = await runner.materializeWorktree(
          ref: fromSha,
          repoRoot: projectRoot,
          parent: scratchBase,
          name: 'wt-from',
        );
        worktrees['to'] = await runner.materializeWorktree(
          ref: toSha,
          repoRoot: projectRoot,
          parent: scratchBase,
          name: 'wt-to',
        );
        await runner.setupWorktree(worktrees['from']!);
        await runner.setupWorktree(worktrees['to']!);
      } on DifferentialRefException catch (e) {
        print('zfa tdd corpus differential: ${e.message}');
        summary(
          entries: entries.length,
          compared: 0,
          differing: 0,
          errors: 0,
          result: 'runner-error',
        );
        exitCode = _exitRunnerError;
        return;
      } on DifferentialSetupException catch (e) {
        print('zfa tdd corpus differential: ${e.message}');
        summary(
          entries: entries.length,
          compared: 0,
          differing: 0,
          errors: 0,
          result: 'runner-error',
        );
        exitCode = _exitRunnerError;
        return;
      }

      // Drive both refs, compare, report.
      var compared = 0;
      var differing = 0;
      for (final entry in entries) {
        final EntryVector fromVector;
        final EntryVector toVector;
        try {
          fromVector = await runner.runEntry(
            entry: entry,
            ref: from,
            worktreePath: worktrees['from']!,
            scratch: Directory(p.join(scratchBase.path, '${entry.name}-from'))
              ..createSync(recursive: true),
          );
          toVector = await runner.runEntry(
            entry: entry,
            ref: to,
            worktreePath: worktrees['to']!,
            scratch: Directory(p.join(scratchBase.path, '${entry.name}-to'))
              ..createSync(recursive: true),
          );
        } on DifferentialSetupException catch (e) {
          print('zfa tdd corpus differential: ${e.message}');
          summary(
            entries: entries.length,
            compared: compared,
            differing: differing,
            errors: 1,
            result: 'runner-error',
          );
          exitCode = _exitRunnerError;
          return;
        } on FileSystemException catch (e) {
          print(
            'zfa tdd corpus differential: scratch setup failed for '
            '${entry.name}: ${e.message}',
          );
          summary(
            entries: entries.length,
            compared: compared,
            differing: differing,
            errors: 1,
            result: 'runner-error',
          );
          exitCode = _exitRunnerError;
          return;
        }

        compared++;
        final findings = compareEntryVectors(from: fromVector, to: toVector);
        if (findings.isEmpty) {
          print('[diff] ${entry.name} -> match');
          continue;
        }
        differing++;
        print(
          '[diff] ${entry.name} -> differ (${fromVector.outcomeSummary} '
          'vs ${toVector.outcomeSummary})',
        );
        for (final f in findings) {
          print('   ${f.kind}: ${f.detail}');
        }
      }

      final result = differing > 0 ? 'differ' : 'match';
      summary(
        entries: entries.length,
        compared: compared,
        differing: differing,
        errors: 0,
        result: result,
      );
      exitCode = differing > 0 ? _exitDiffer : _exitMatch;
    } finally {
      // Worktrees are always removed (metadata + dir via git); the
      // scratch dirs survive only under --keep-scratch.
      for (final wt in worktrees.values) {
        try {
          await runner.removeWorktree(path: wt, repoRoot: projectRoot);
        } on Object {
          // Removal must never mask the run's verdict.
        }
      }
      if (!keepScratch && _scratchRootOverride == null) {
        try {
          await scratchBase.delete(recursive: true);
        } on Object {
          // Same: cleanup is best-effort, the verdict stands.
        }
      } else if (!keepScratch) {
        // Test-injected scratch root: clean per-entry dirs, keep the
        // root the test owns.
        for (final child in scratchBase.listSync()) {
          if (child is Directory &&
              (p.basename(child.path).endsWith('-from') ||
                  p.basename(child.path).endsWith('-to'))) {
            try {
              await child.delete(recursive: true);
            } on Object {
              // Best-effort.
            }
          }
        }
      }
    }
  }

  static String _short(String sha) =>
      sha.length <= 12 ? sha : sha.substring(0, 12);
}
