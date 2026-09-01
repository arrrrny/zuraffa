/// `StepRunner` — spawns the TDD step commands as sub-processes of the zfa
/// CLI and consumes their machine-readable contracts (spec 049-tdd-run,
/// FR-002 / U12-U18).
///
/// Each step runs as `tdd <step> <behavior-id>` plus `--feature <f>` and
/// `--project <dir>` flags through the resolved zfa entrypoint (a
/// sub-process, so a step crash cannot corrupt driver state). Success is
/// the step's exit code AND its documented summary line agreeing:
///
/// - `gen` — exit 0 (no summary-line requirement, U16);
/// - `verify-red` — exit 0 and `certified=true` (U13);
/// - `make` — exit 0 and `outcome=green` (U14);
/// - `refactor` — exit 0 and `outcome=clean` or `outcome=refactored`
///   (U15).
///
/// The entrypoint is the `--zfa-bin` override when given (U18), else
/// resolved via `Platform.script` with `Isolate.resolvePackageUri` as
/// fallback (handles both normal CLI runs and test contexts). A `.dart`
/// entrypoint is run through `dart`; anything else is executed directly.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Spawn hook so fast-tier tests can drive the parser without real
/// processes (the slow tier exercises the real spawn path with the
/// fixture's fake zfa binary).
typedef StepSpawner =
    Future<ProcessResult> Function(
      List<String> command,
      String workingDirectory,
    );

/// One step invocation's machine-readable outcome.
class StepResult {
  const StepResult({
    required this.step,
    required this.behaviorId,
    required this.exitCode,
    required this.outcome,
    required this.success,
    required this.output,
  });

  final String step;
  final String behaviorId;
  final int exitCode;

  /// The step's outcome token: `ok`/`certified`/`green`/`clean`/
  /// `refactored` on success; the step's own failure class (its
  /// classification or outcome field) or `runner-error`/`missing-summary`
  /// otherwise.
  final String outcome;
  final bool success;

  /// The step's combined stdout + stderr (for failure reports).
  final String output;

  @override
  String toString() =>
      'StepResult(step: $step, behavior: $behaviorId, exit: $exitCode, '
      'outcome: $outcome, success: $success)';
}

class StepRunner {
  StepRunner({this.zfaBin, StepSpawner? spawner})
    : _spawner = spawner ?? _defaultSpawner;

  /// Explicit entrypoint override (`--zfa-bin`). When null the package
  /// root's `bin/zfa.dart` is resolved.
  final String? zfaBin;

  final StepSpawner _spawner;

  /// Resolved entrypoint, cached after the first step so `defaultZfaBin`'s
  /// `Isolate.resolvePackageUri` lookup runs once per run, not once per step
  /// (minor finding from the review of #608).
  String? _resolvedEntry;

  static const stepOrder = ['gen', 'verify-red', 'make', 'refactor'];

  /// Resolve this package's `bin/zfa.dart` (the entrypoint the driver
  /// spawns when `--zfa-bin` is absent).
  ///
  /// Uses `Platform.script` to derive the entrypoint — the same runtime
  /// that is currently executing — so this works regardless of whether
  /// zuraffa is on the package path or running as a compiled snapshot.
  ///
  /// Resolution order:
  ///   1. `Platform.script` when its basename is `zfa.dart` or `zuraffa.dart`
  ///      (running from the entrypoint directly).
  ///   2. `p.join(dirname(Platform.script), 'bin', 'zfa.dart')` — handles
  ///      compiled-snapshot / global-activate where the script is a sibling
  ///      of `bin/`.
  ///   3. `Isolate.resolvePackageUri` fallback — handles test contexts where
  ///      `Platform.script` points at the test runner.
  static Future<String> defaultZfaBin() async {
    final script = Platform.script;
    if (script.scheme == 'file') {
      final scriptPath = script.toFilePath();
      final base = p.basename(scriptPath);
      if (base == 'zfa.dart' || base == 'zuraffa.dart') {
        // Running from bin/zfa.dart or bin/zuraffa.dart — already the entrypoint.
        return scriptPath;
      }
      // Running from a compiled snapshot or sibling path.
      final derived = p.join(p.dirname(scriptPath), 'bin', 'zfa.dart');
      if (await File(derived).exists()) return derived;
      // Fall through: the derived path may not exist (e.g. test runner).
    }
    // Fallback: resolve via the package path (handles test contexts where
    // Platform.script points at the test kernel).
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:zuraffa/src/zfa_cli.dart'),
    );
    if (uri != null) {
      // <pkg>/lib/src/zfa_cli.dart -> <pkg>/bin/zfa.dart
      final bin = p.join(
        p.dirname(p.dirname(p.dirname(p.fromUri(uri)))),
        'bin',
        'zfa.dart',
      );
      if (await File(bin).exists()) return bin;
    }
    // Fallback: Platform.script (compiled snapshot / global activate).
    final scriptPath = Platform.script.toFilePath();
    if (await File(scriptPath).exists()) return scriptPath;
    throw StateError(
      'cannot resolve the zfa entrypoint (package:zuraffa is not on the '
      'package path and Platform.script is not a usable file); '
      'pass --zfa-bin explicitly',
    );
  }

  /// Run one step for [behaviorId] and map the sub-process result onto the
  /// step's contract. A spawn failure yields a `runner-error` StepResult,
  /// never a crash (U17).
  Future<StepResult> run({
    required String step,
    required String behaviorId,
    required String feature,
    required String projectRoot,
  }) async {
    if (!stepOrder.contains(step)) {
      throw ArgumentError.value(step, 'step', 'unknown TDD step');
    }
    final entry = _resolvedEntry ??= zfaBin ?? await defaultZfaBin();
    final argv = [
      'tdd',
      step,
      behaviorId,
      '--feature',
      feature,
      '--project',
      projectRoot,
    ];
    final command = entry.endsWith('.dart')
        ? ['dart', entry, ...argv]
        : [entry, ...argv];

    final ProcessResult process;
    try {
      process = await _spawner(command, projectRoot);
    } on ProcessException catch (e) {
      return StepResult(
        step: step,
        behaviorId: behaviorId,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: 'spawn failed for ${command.first}: ${e.message}',
      );
    } on IOException catch (e) {
      return StepResult(
        step: step,
        behaviorId: behaviorId,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: 'spawn failed for ${command.first}: $e',
      );
    }

    final stdout = process.stdout.toString();
    final stderr = process.stderr.toString();
    final output = stderr.isEmpty ? stdout : '$stdout\n$stderr';
    final kv = _parseSummaryLine(step, stdout);
    final exitOk = process.exitCode == 0;

    switch (step) {
      case 'gen':
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: exitOk ? 'ok' : 'error',
          success: exitOk,
          output: output,
        );
      case 'verify-red':
        final certified = kv != null && kv['certified'] == 'true';
        final outcome = certified
            ? 'certified'
            : (kv?['classification'] ??
                  (exitOk ? 'missing-summary' : 'failed'));
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: outcome,
          success: exitOk && certified,
          output: output,
        );
      case 'make':
      case 'refactor':
        final outcome =
            kv?['outcome'] ?? (exitOk ? 'missing-summary' : 'failed');
        final success =
            exitOk &&
            (step == 'make'
                ? outcome == 'green'
                : outcome == 'clean' || outcome == 'refactored');
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: outcome,
          success: success,
          output: output,
        );
    }
    // Unreachable: step validated against stepOrder above.
    throw StateError('unhandled step $step');
  }

  /// The last `<step>: key=value ...` line in [stdout], parsed into a map —
  /// the step commands' machine contract (FR-002). Returns null when the
  /// step printed no summary line.
  static Map<String, String>? _parseSummaryLine(String step, String stdout) {
    Map<String, String>? last;
    for (final line in stdout.split('\n')) {
      if (!line.startsWith('$step: ')) continue;
      final fields = <String, String>{};
      for (final match in RegExp(
        r'(\w+)=([^\s]+)',
      ).allMatches(line.substring(step.length + 2))) {
        fields[match.group(1)!] = match.group(2)!;
      }
      last = fields;
    }
    return last;
  }

  static Future<ProcessResult> _defaultSpawner(
    List<String> command,
    String workingDirectory,
  ) {
    return Process.run(
      command.first,
      command.sublist(1),
      workingDirectory: workingDirectory,
    );
  }
}
