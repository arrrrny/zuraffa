/// The differential ref runner (bug #805 — generator differential
/// testing, vision slice v0).
///
/// Drives one corpus entry against one materialized generator ref and
/// records the behavioral [EntryVector]:
///
/// 1. the entry's `project/` scaffold is copied into a fresh scratch
///    dir and its dependencies resolved (`dart pub get`);
/// 2. each step spawns through the ref's worktree entrypoint
///    (`dart <worktree>/bin/zfa.dart <argv> --project <scratch>`) or,
///    for `dart ...` steps, directly in the scratch project, under one
///    wall-clock budget (the #742 primitive — a child that outlives it
///    is killed and the step records the `hang` outcome, the #744
///    class);
/// 3. the vector records each step's exit code, outcome class, machine
///    token (gen's JSON verdict / make's `outcome=` / the `result=`
///    contract), dart-test pass/fail counts, and the sorted artifact
///    inventory under the entry's roots — paths, not bytes.
///
/// All spawns go through the injectable [DifferentialSpawner] (the
/// #049/#051 fake-bin pattern), so fast-tier tests script the
/// generator's behavior without a real worktree.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/differential_vector.dart';
import 'differential_corpus.dart';
import 'tdd_timeout.dart';

/// The subprocess spawner hook (injectable for fast-tier tests).
typedef DifferentialSpawner =
    Future<ProcessResult> Function(
      List<String> command,
      String workingDirectory,
    );

/// The git invocation hook (injectable for fast-tier tests).
typedef DifferentialGitRunner =
    Future<ProcessResult> Function(List<String> args, String workingDirectory);

/// Thrown when a git ref does not resolve or a worktree cannot be
/// materialized — the runner-error class, never a crash.
class DifferentialRefException implements Exception {
  DifferentialRefException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when a dependency-resolution step (`dart pub get` in a
/// worktree or a scratch project) fails — the generator under test can
/// not even be set up, so no vector exists for it.
class DifferentialSetupException implements Exception {
  DifferentialSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The per-ref default step budget: gen's own internal flow budget is
/// 30s (#748), make's pipeline budget 10 min; the differential needs
/// to bound the WHOLE step, so 5 minutes bounds every current step
/// kind while leaving the hang kill well under the 20-minute gate.
const Duration defaultDifferentialBudget = Duration(minutes: 5);

class DifferentialRefRunner {
  DifferentialRefRunner({
    DifferentialSpawner? spawner,
    DifferentialGitRunner? gitRunner,
    Duration? budget,
  }) : budget = budget ?? defaultDifferentialBudget,
       _spawner =
           spawner ??
           ((List<String> command, String workingDirectory) => runTimed(
             command.first,
             command.sublist(1),
             workingDirectory: workingDirectory,
             timeout: budget ?? defaultDifferentialBudget,
           )),
       _gitRunner =
           gitRunner ??
           ((List<String> args, String workingDirectory) =>
               Process.run('git', args, workingDirectory: workingDirectory));

  /// The per-step wall-clock budget. A child that outlives it is
  /// killed and records the `hang` outcome.
  final Duration budget;

  final DifferentialSpawner _spawner;
  final DifferentialGitRunner _gitRunner;

  /// Resolves a ref to its commit sha; an unknown ref throws
  /// [DifferentialRefException].
  Future<String> resolveRef(String ref, {required String repoRoot}) async {
    final result = await _gitRunner([
      'rev-parse',
      '--verify',
      '$ref^{commit}',
    ], repoRoot);
    if (result.exitCode != 0) {
      throw DifferentialRefException(
        'unknown git ref "$ref" (${result.stderr.toString().trim()})',
      );
    }
    final sha = result.stdout.toString().trim();
    if (sha.isEmpty) {
      throw DifferentialRefException('unknown git ref "$ref" (no commit)');
    }
    return sha;
  }

  /// Materializes [ref] as a detached worktree under [parent] and
  /// returns the worktree path.
  Future<String> materializeWorktree({
    required String ref,
    required String repoRoot,
    required Directory parent,
    String? name,
  }) async {
    final worktreePath = p.join(parent.path, name ?? 'wt-${ref.hashCode}');
    final result = await _gitRunner([
      'worktree',
      'add',
      '--detach',
      worktreePath,
      ref,
    ], repoRoot);
    if (result.exitCode != 0) {
      throw DifferentialRefException(
        'git worktree add failed for "$ref": '
        '${result.stderr.toString().trim()}',
      );
    }
    if (!Directory(worktreePath).existsSync()) {
      throw DifferentialRefException(
        'git worktree add did not materialize $worktreePath',
      );
    }
    return worktreePath;
  }

  /// Removes a materialized worktree (metadata + directory) via git.
  Future<void> removeWorktree({
    required String path,
    required String repoRoot,
  }) async {
    await _gitRunner(['worktree', 'remove', '--force', path], repoRoot);
  }

  /// Resolves the generator's dependencies inside a worktree. A setup
  /// failure is a [DifferentialSetupException] — no vector exists for
  /// an unresolvable ref.
  Future<void> setupWorktree(String worktreePath) async {
    final result = await _spawner([
      'dart',
      'pub',
      'get',
      '--no-example',
    ], worktreePath);
    if (result.exitCode != 0) {
      throw DifferentialSetupException(
        'dart pub get failed in worktree $worktreePath: '
        '${result.stderr.toString().trim()}',
      );
    }
  }

  /// Drives [entry] against the generator materialized at
  /// [worktreePath], copying the scaffold into [scratch]/project, and
  /// returns the behavioral vector.
  Future<EntryVector> runEntry({
    required DifferentialEntry entry,
    required String ref,
    required String worktreePath,
    required Directory scratch,
  }) async {
    final scratchProject = Directory(p.join(scratch.path, 'project'));
    if (scratchProject.existsSync()) {
      scratchProject.deleteSync(recursive: true);
    }
    _copyProject(Directory(entry.projectDir), scratchProject);

    final pubGet = await _spawner([
      'dart',
      'pub',
      'get',
      '--no-example',
    ], scratchProject.path);
    if (pubGet.exitCode != 0) {
      throw DifferentialSetupException(
        'dart pub get failed in scratch project ${scratchProject.path}: '
        '${pubGet.stderr.toString().trim()}',
      );
    }

    final worktreeBin = p.join(worktreePath, 'bin', 'zfa.dart');
    final steps = <StepVector>[];
    for (final step in entry.steps) {
      steps.add(await _runStep(step, worktreeBin, scratchProject));
    }

    return EntryVector(
      entry: entry.name,
      ref: ref,
      steps: steps,
      artifacts: _collectArtifacts(scratchProject, entry.artifactRoots),
    );
  }

  Future<StepVector> _runStep(
    DifferentialStepSpec step,
    String worktreeBin,
    Directory scratchProject,
  ) async {
    final List<String> command;
    if (step.argv.first == 'dart') {
      command = [...step.argv];
    } else {
      command = [
        'dart',
        worktreeBin,
        ...step.argv,
        '--project',
        scratchProject.path,
      ];
    }

    final ProcessResult process;
    try {
      process = await _spawner(command, scratchProject.path);
    } on ProcessTimeoutException {
      // The #744 class: the child outlived the budget and was killed.
      // Recorded as the step's behavior, never a runner misfire.
      return StepVector(
        label: step.label,
        exitCode: -1,
        outcome: DifferentialStepOutcome.hang,
      );
    } on ProcessException catch (e) {
      return StepVector(
        label: step.label,
        exitCode: -1,
        outcome: DifferentialStepOutcome.failed,
        token: 'spawn-failed: ${e.message}',
      );
    }

    final stdoutText = process.stdout.toString();
    final stderrText = process.stderr.toString();
    final output = stderrText.isEmpty ? stdoutText : '$stdoutText\n$stderrText';

    int? pass;
    int? fail;
    if (step.isTestStep) {
      final counts = parseTestCounts(output);
      pass = counts?.$1;
      fail = counts?.$2;
    }

    return StepVector(
      label: step.label,
      exitCode: process.exitCode,
      outcome: process.exitCode == 0
          ? DifferentialStepOutcome.complete
          : DifferentialStepOutcome.failed,
      token: extractMachineToken(stdoutText),
      passCount: pass,
      failCount: fail,
    );
  }

  /// The sorted relative artifact paths under [roots] inside the
  /// scratch project. Roots that do not exist are skipped (an entry
  /// may legitimately generate nothing); paths are posix-normalized so
  /// the inventory is comparable across platforms.
  List<String> _collectArtifacts(Directory scratchProject, List<String> roots) {
    final artifacts = <String>[];
    for (final root in roots) {
      final dir = Directory(p.join(scratchProject.path, root));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          artifacts.add(
            p.posix.joinAll(
              p.split(p.relative(entity.path, from: scratchProject.path)),
            ),
          );
        }
      }
    }
    return artifacts..sort();
  }

  static void _copyProject(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final entity in from.listSync()) {
      final target = p.join(to.path, p.basename(entity.path));
      if (entity is Directory) {
        _copyProject(entity, Directory(target));
      } else if (entity is File) {
        File(target).writeAsBytesSync(entity.readAsBytesSync());
      }
    }
  }

  /// Parses the machine token from a step's stdout: gen's final JSON
  /// verdict (`verdict` field, bug #840), then make's
  /// `make: ... outcome=<label>` summary, then the generic `result=`
  /// contract (run/corpus style). Null when no contract spoke.
  static String? extractMachineToken(String stdout) {
    final lines = stdout.split('\n').reversed;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final json = jsonDecode(trimmed);
          if (json is Map<String, dynamic> && json['verdict'] is String) {
            return json['verdict'] as String;
          }
        } on FormatException {
          // Not JSON after all; keep scanning.
        }
      }
      break;
    }
    final makeMatch = RegExp(r'make: .*outcome=(\S+)').firstMatch(stdout);
    if (makeMatch != null) return makeMatch.group(1);
    String? lastResult;
    for (final match in RegExp(r'result=(\S+)').allMatches(stdout)) {
      lastResult = match.group(1);
    }
    return lastResult;
  }

  /// The final dart-test counters line: `+<pass>` optionally followed
  /// by ` -<fail>`. Null when the output carries no counters.
  static (int, int)? parseTestCounts(String output) {
    final matches = RegExp(r'\+(\d+)(?:\s+-(\d+))?').allMatches(output);
    if (matches.isEmpty) return null;
    final last = matches.last;
    return (
      int.parse(last.group(1)!),
      last.group(2) == null ? 0 : int.parse(last.group(2)!),
    );
  }
}
