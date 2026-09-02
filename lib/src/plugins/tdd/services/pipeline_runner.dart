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
///      case; a native AOT executable resolves to itself alone — bug
///      #864 — the binary path is never doubled). An unresolvable
///      entrypoint misfire-stops before any step executes (U12).
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
import 'tdd_timeout.dart';

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

  /// The default per-step address-space ceiling (bug #826): 2 GiB in KB —
  /// measured generous enough for the analyzer/build pipeline a real
  /// `zfa make`/`zfa build` child loads (a 1 GiB ceiling makes the child
  /// abort deterministically on a plain hello-world-grade CLI start;
  /// 2 GiB lets legitimate generation complete) while staying under
  /// typical CI machine ceilings so an allocation failure lands INSIDE
  /// the child — deterministic, classified — instead of the OS OOM
  /// killer firing mid-loop (nondeterministic SIGKILL, the bug #826
  /// signature).
  static const defaultStepMemoryKb = 2 * 1024 * 1024;

  /// The environment variable overriding [defaultStepMemoryKb] (bug #826).
  /// A value of `0` opts out of the bound entirely (unbounded child);
  /// garbage falls back to the default instead of guessing.
  static const stepMemoryEnv = 'ZFA_TDD_STEP_MEMORY_KB';

  /// Resolve the per-step address-space ceiling in KB, or null when no
  /// bound applies: Windows (no ulimit equivalent — the deadline and the
  /// kill classification still apply), or an explicit `0` override.
  ///
  /// [isWindows] is injectable for tests; it defaults to the real
  /// platform check.
  static int? resolveStepMemoryLimitKb(
    Map<String, String> environment, {
    bool? isWindows,
  }) {
    if (isWindows ?? Platform.isWindows) return null;
    final raw = environment[stepMemoryEnv];
    if (raw == null || raw.trim().isEmpty) return defaultStepMemoryKb;
    final parsed = int.tryParse(raw.trim());
    // Garbage (unparseable, negative) falls back to the default bound —
    // the safe reading — while an explicit `0` opts out entirely.
    if (parsed == null || parsed < 0) return defaultStepMemoryKb;
    if (parsed == 0) return null;
    return parsed;
  }

  /// Execute [plan] in [workingDirectory]. Returns the captured
  /// steps and completion status.
  ///
  /// [zfaBinOverride] (when set) replaces the entrypoint auto-resolution
  /// (U11); useful in tests to point at a fake zfa script.
  ///
  /// [timeout] is the per-step hard deadline (bug #742): a hanging step
  /// child is killed and captured as a [GenerationStep] with `timedOut:
  /// true`, the plan stops there (misfire-stop), and never hangs. Defaults
  /// to [TddTimeouts.defaultPipelineStep].
  ///
  /// Bug #826: every step child also spawns under a bounded address-space
  /// ceiling [resolveStepMemoryLimitKb] — 2 GiB by default, `--no-bound` via
  /// `ZFA_TDD_STEP_MEMORY_KB=0`), so a runaway analyzer/build pipeline
  /// dies deterministically inside the child instead of the OS OOM killer
  /// SIGKILLing it mid-loop. A killed step is captured with a CLASSIFIED
  /// verdict — `resource-limit` (signal death, the OOM class) or
  /// `timeout` (our deadline) — plus resource telemetry (RSS before/after,
  /// wall clock); it is never graded as a bare generation failure.
  ///
  /// [scriptPathOverride], [resolvedExecutableOverride] and
  /// [pathEnvOverride] are platform-fact seams (bug #864): they replace
  /// `Platform.script.toFilePath()`, `Platform.resolvedExecutable` and
  /// `Platform.environment['PATH']` during entrypoint resolution so
  /// tests can pin every tier (source, PATH, compiled snapshot, native
  /// executable) without spawning a real VM. Production callers omit
  /// them and get the real platform values.
  Future<PipelineResult> runPlan({
    required GenerationPlan plan,
    required String workingDirectory,
    String? zfaBinOverride,
    String? feature,
    Duration? timeout,
    String? scriptPathOverride,
    String? resolvedExecutableOverride,
    String? pathEnvOverride,
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
      scriptPathOverride: scriptPathOverride,
      resolvedExecutableOverride: resolvedExecutableOverride,
      pathEnvOverride: pathEnvOverride,
    );

    final memoryLimitKb = resolveStepMemoryLimitKb(Platform.environment);

    final captured = <GenerationStep>[];
    var firstFailure = -1;
    for (var i = 0; i < plan.steps.length; i++) {
      final spec = plan.steps[i];
      final args = [...entrypoint.arguments, ...spec.args];
      final fullCmd = '${entrypoint.displayCommand} ${spec.args.join(' ')}';
      final clock = Stopwatch()..start();
      final rssBeforeKb = ProcessInfo.currentRss ~/ 1024;
      try {
        final result = await runTimed(
          entrypoint.executable,
          args,
          workingDirectory: workingDirectory,
          runInShell: false,
          timeout: timeout ?? TddTimeouts.defaultPipelineStep,
          memoryLimitKb: memoryLimitKb,
        );
        final telemetry = _telemetry(clock, rssBeforeKb);
        final output = '${result.stdout}${result.stderr}';
        // Bug #826: Dart reports a signal-killed child as a NEGATIVE exit
        // code (SIGKILL is -9). That death is the OOM/resource-pressure
        // class — classify it; every ordinary exit (zero or not) stays
        // unclassified.
        final killClass = result.exitCode < 0
            ? GenerationKillClass.resourceLimit
            : GenerationKillClass.none;
        captured.add(
          GenerationStep(
            command: fullCmd,
            exitCode: result.exitCode,
            output: output,
            purpose: spec.purpose,
            killClass: killClass,
            telemetry: telemetry,
          ),
        );
        if (result.exitCode != 0) {
          firstFailure = i;
          break;
        }
      } on ProcessTimeoutException catch (e) {
        // Bug #742: a step that outlived the deadline was killed — capture
        // the timeout honestly and stop the plan (misfire-stop). Bug #826:
        // the capture now carries the classified `timeout` verdict and the
        // resource telemetry instead of a bare failure.
        captured.add(
          GenerationStep(
            command: fullCmd,
            exitCode: -1,
            output: e.toString(),
            purpose: spec.purpose,
            timedOut: true,
            killClass: GenerationKillClass.timeout,
            telemetry: _telemetry(clock, rssBeforeKb),
          ),
        );
        firstFailure = i;
        break;
      } on ProcessException catch (e) {
        captured.add(
          GenerationStep(
            command: fullCmd,
            exitCode: -1,
            output: 'Failed to start "${entrypoint.displayCommand}": $e',
            purpose: spec.purpose,
            telemetry: _telemetry(clock, rssBeforeKb),
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

  /// The resource telemetry captured around one step's subprocess (bug
  /// #826): the spawning process's RSS before/after and the child's wall
  /// clock. Observability only — never used in decisions.
  StepTelemetry _telemetry(Stopwatch clock, int rssBeforeKb) => StepTelemetry(
    rssBeforeKb: rssBeforeKb,
    rssAfterKb: ProcessInfo.currentRss ~/ 1024,
    wallClockMs: clock.elapsedMilliseconds,
  );

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
  ///   4. Fallback: `Platform.script` is a `file://` URL but the basename
  ///      is not `zfa.dart`/`zuraffa.dart`.
  ///      - Native AOT executable (bug #864): `Platform.script` IS
  ///        `Platform.resolvedExecutable` — the entrypoint is the
  ///        executable alone (no doubled binary path).
  ///      - Otherwise (compiled snapshot / global activate): use
  ///        `dart <Platform.script.toFilePath()>`.
  ///
  /// Misfire-stop (U12): throws [PipelineResolutionError] when nothing
  /// resolves.
  ///
  /// The `*Override` parameters are platform-fact test seams (bug #864);
  /// see [runPlan].
  Future<_ResolvedEntrypoint> _resolveEntrypoint({
    required String? zfaBinOverride,
    required String workingDirectory,
    String? feature,
    String? scriptPathOverride,
    String? resolvedExecutableOverride,
    String? pathEnvOverride,
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
    final resolvedExecutable =
        resolvedExecutableOverride ?? Platform.resolvedExecutable;
    final String? scriptPath = scriptPathOverride ?? _platformScriptPath();
    if (scriptPath != null) {
      final base = p.basename(scriptPath);
      // bin/zfa.dart or bin/zuraffa.dart — invoke via the dart binary.
      if (base == 'zfa.dart' || base == 'zuraffa.dart') {
        return _ResolvedEntrypoint(
          executable: resolvedExecutable,
          arguments: [scriptPath],
          displayCommand: '$resolvedExecutable $scriptPath',
        );
      }
      // Non-standard basename: fall through to PATH lookup (tier 3),
      // then to the compiled-snapshot fallback (tier 4) if PATH also fails.
    }

    // 3. Resolve the concrete `zfa` executable from PATH without a shell.
    final pathEntrypoint = _findExecutableOnPath(
      'zfa',
      pathEnv: pathEnvOverride,
    );
    if (pathEntrypoint != null) {
      return _ResolvedEntrypoint(
        executable: pathEntrypoint,
        displayCommand: pathEntrypoint,
      );
    }

    // 4. Final fallback: resolvedExecutable + Platform.script.
    //    Catches compiled-snapshot and global-activate scenarios where
    //    Platform.script basename is not zfa.dart/zuraffa.dart.
    if (scriptPath != null) {
      // Bug #864: a native AOT executable (`dart compile exe`) has no
      // source script and no snapshot — `Platform.script` IS the
      // executable itself. The old unconditional `<dart> <scriptPath>`
      // shape doubled the binary path: the child received the exe path
      // as its first argument, printed usage, and every generation step
      // failed with exit 64. Invoke the executable alone. The
      // `<resolvedExecutable> <scriptPath>` shape stays for real
      // script/snapshot cases (source, JIT snapshot, global activate),
      // which is why the equality check — not the basename — decides.
      final isNativeExecutable = p.equals(scriptPath, resolvedExecutable);
      return _ResolvedEntrypoint(
        executable: resolvedExecutable,
        arguments: isNativeExecutable ? const [] : [scriptPath],
        displayCommand: isNativeExecutable
            ? resolvedExecutable
            : '$resolvedExecutable $scriptPath',
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

  /// The file path behind `Platform.script`, or null when the running
  /// script is not a `file://` URL.
  String? _platformScriptPath() {
    final script = Platform.script;
    return script.scheme == 'file' ? script.toFilePath() : null;
  }

  String? _findExecutableOnPath(String name, {String? pathEnv}) {
    final path = pathEnv ?? Platform.environment['PATH'];
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
