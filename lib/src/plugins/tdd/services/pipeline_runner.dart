/// `PipelineRunner` — executes a [GenerationPlan]'s steps in order
/// via `Process.run`, capturing each step's command + exit code +
/// output (spec 047-tdd-make T006; FR-006; data-model.md).
///
/// Responsibilities:
///   1. Resolve the zfa entrypoint: `--zfa-bin` override → running
///      CLI's `Platform.script` when launched from source (a `file://`
///      URL ending in `/bin/zfa.dart` or `/bin/zuraffa.dart`) → `zfa`
///      on PATH (FR-004 / U11). An unresolvable entrypoint misfire-
///      stops before any step executes (U12).
///   2. For each [GenerationStepSpec], run `zfa <args...>` via
///      `Process.run` in the target project's working directory
///      (FR-004 / U13). Capture the full resolved command line, the
///      exit code, and the combined stdout+stderr as a
///      [GenerationStep].
///   3. Stop the plan on the first failing step (U10): later steps
///      never execute when an earlier one fails. The captured steps
///      include the failure; the caller decides what to do with them.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation_plan.dart';

/// Resolution-stage failure: the zfa entrypoint could not be resolved
/// or is missing on disk. Carries the feature context if known.
class PipelineResolutionError implements Exception {
  PipelineResolutionError(this.message, {this.feature});

  final String message;
  final String? feature;

  @override
  String toString() => message;
}

/// Result of running a [GenerationPlan]: the captured steps (in
/// execution order), whether the plan completed (`false` if any step
/// failed), and the index of the first failing step (-1 if none).
class PipelineResult {
  final List<GenerationStep> steps;
  final bool completed;
  final int firstFailureIndex;
  final String entrypoint;

  const PipelineResult({
    required this.steps,
    required this.completed,
    required this.firstFailureIndex,
    required this.entrypoint,
  });

  @override
  String toString() =>
      'PipelineResult(entrypoint: $entrypoint, ${steps.length} steps, '
      'completed: $completed, firstFailure: $firstFailureIndex)';
}

class PipelineRunner {
  const PipelineRunner();

  /// Execute [plan] in [workingDirectory]. Returns the captured
  /// steps and completion status.
  ///
  /// [zfaBinOverride] (when set) replaces the entrypoint auto-resolution
  /// (U11); useful in tests to point at a fake zfa script.
  Future<PipelineResult> runPlan({
    required GenerationPlan plan,
    required String workingDirectory,
    String? zfaBinOverride,
    String? feature,
  }) async {
    if (!plan.isExpressible) {
      return PipelineResult(
        steps: const [],
        completed: false,
        firstFailureIndex: -1,
        entrypoint: '(unexpressible plan)',
      );
    }
    final entrypoint = await _resolveEntrypoint(
      zfaBinOverride: zfaBinOverride,
      workingDirectory: workingDirectory,
      feature: feature,
    );

    final captured = <GenerationStep>[];
    var firstFailure = -1;
    for (var i = 0; i < plan.steps.length; i++) {
      final spec = plan.steps[i];
      final args = [...entrypoint.arguments, ...spec.args];
      final fullCmd = '${entrypoint.displayCommand} ${spec.args.join(' ')}';
      try {
        final result = await Process.run(
          entrypoint.executable,
          args,
          workingDirectory: workingDirectory,
          runInShell: false,
        );
        final output = '${result.stdout}${result.stderr}';
        captured.add(
          GenerationStep(
            command: fullCmd,
            exitCode: result.exitCode,
            output: output,
            purpose: spec.purpose,
          ),
        );
        if (result.exitCode != 0) {
          firstFailure = i;
          break;
        }
      } on ProcessException catch (e) {
        captured.add(
          GenerationStep(
            command: fullCmd,
            exitCode: -1,
            output: 'Failed to start "${entrypoint.displayCommand}": $e',
            purpose: spec.purpose,
          ),
        );
        firstFailure = i;
        break;
      }
    }
    return PipelineResult(
      steps: captured,
      completed: firstFailure == -1,
      firstFailureIndex: firstFailure,
      entrypoint: entrypoint.displayCommand,
    );
  }

  /// Resolve the zfa entrypoint (FR-004 / U11, U12).
  ///
  /// Order:
  ///   1. [zfaBinOverride] (the `--zfa-bin` flag) when set and the
  ///      target is an executable file.
  ///   2. `Platform.script` when this CLI is running from source — a
  ///      `file://` URL whose path ends in `/bin/zfa.dart` or
  ///      `/bin/zuraffa.dart`. The entrypoint is `dart <that path>`.
  ///   3. `zfa` on PATH — verified to be on PATH via
  ///      a direct lookup of the executable in `PATH`.
  ///
  /// Misfire-stop (U12): throws [PipelineResolutionError] when nothing
  /// resolves.
  Future<_ResolvedEntrypoint> _resolveEntrypoint({
    required String? zfaBinOverride,
    required String workingDirectory,
    String? feature,
  }) async {
    // 1. Explicit override.
    if (zfaBinOverride != null && zfaBinOverride.isNotEmpty) {
      final f = File(zfaBinOverride);
      if (!await f.exists()) {
        throw PipelineResolutionError(
          'zfa tdd make: --zfa-bin "$zfaBinOverride" does not exist on '
          'disk. Provide a path to a real zfa entrypoint.',
          feature: feature,
        );
      }
      return _ResolvedEntrypoint(
        executable: zfaBinOverride,
        displayCommand: zfaBinOverride,
      );
    }

    // 2. Running CLI from source (Platform.script).
    final script = Platform.script;
    if (script.scheme == 'file') {
      final scriptPath = script.toFilePath();
      final base = p.basename(scriptPath);
      // bin/zfa.dart or bin/zuraffa.dart — invoke via the dart binary.
      if (base == 'zfa.dart' || base == 'zuraffa.dart') {
        return _ResolvedEntrypoint(
          executable: Platform.resolvedExecutable,
          arguments: [scriptPath],
          displayCommand: '${Platform.resolvedExecutable} $scriptPath',
        );
      }
      // In tests, Platform.script points at the test runner — fall
      // through to option 3.
    }

    // 3. Resolve the concrete `zfa` executable from PATH without a shell.
    final pathEntrypoint = _findExecutableOnPath('zfa');
    if (pathEntrypoint != null) {
      return _ResolvedEntrypoint(
        executable: pathEntrypoint,
        displayCommand: pathEntrypoint,
      );
    }

    throw PipelineResolutionError(
      'zfa tdd make: cannot resolve the zfa entrypoint. The command '
      'needs to invoke `zfa entity create` / `zfa make` / `zfa build` '
      'as sub-processes, but neither --zfa-bin, Platform.script '
      '(running from source), nor `zfa` on PATH resolved. Run from '
      'inside a checkout of zuraffa, or pass --zfa-bin <path>.',
      feature: feature,
    );
  }

  String? _findExecutableOnPath(String name) {
    final path = Platform.environment['PATH'];
    if (path == null || path.isEmpty) return null;
    final extensions = Platform.isWindows
        ? (Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD')
              .split(';')
              .where((extension) => extension.isNotEmpty)
        : const [''];
    for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
      if (directory.isEmpty) continue;
      for (final extension in extensions) {
        final candidate = File(p.join(directory, '$name$extension'));
        if (!candidate.existsSync()) continue;
        if (Platform.isWindows || (candidate.statSync().mode & 0x49) != 0) {
          return candidate.path;
        }
      }
    }
    return null;
  }
}

class _ResolvedEntrypoint {
  const _ResolvedEntrypoint({
    required this.executable,
    required this.displayCommand,
    this.arguments = const [],
  });

  final String executable;
  final List<String> arguments;
  final String displayCommand;
}
