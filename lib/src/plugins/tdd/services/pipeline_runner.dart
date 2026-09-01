/// `PipelineRunner` — executes a [GenerationPlan]'s steps in order
/// via `Process.run`, capturing each step's command + exit code +
/// output (spec 047-tdd-make T006; FR-006; data-model.md).
///
/// Responsibilities:
///   1. Resolve the zfa entrypoint: `--zfa-bin` override → running
///      CLI's `Platform.script` when launched from source (a `file://`
///      URL ending in `/bin/zfa.dart` or `/bin/zuraffa.dart`) → `zfa`
///      on PATH → fallback to `Platform.resolvedExecutable` with
///      `Platform.script` path (handles compiled-snapshot / global-activate
///      case) (FR-004 / U11). An unresolvable entrypoint misfire-
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

import '../models/generation_plan.dart';
import 'zfa_entrypoint.dart';

export 'zfa_entrypoint.dart'
    show PipelineResolutionError, ResolvedZfaEntrypoint, resolveZfaEntrypoint;

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
    final entrypoint = await resolveZfaEntrypoint(
      zfaBinOverride: zfaBinOverride,
      feature: feature,
      commandLabel: 'zfa tdd make',
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
}
