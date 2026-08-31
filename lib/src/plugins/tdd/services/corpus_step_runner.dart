/// `CorpusStepRunner` — spawns the per-feature TDD commands as
/// sub-processes of the zfa CLI and consumes their machine-readable
/// contracts (spec 051-corpus-harness; the same spawn contract
/// `StepRunner` established for the step commands in spec 049).
///
/// - `zfa tdd run <feature> --project <dir>` — exit 0 AND
///   `run: feature=… result=complete` means success; any other result
///   token (`stopped`, `runner-error`, `corrupt-state`, …) plus its
///   `stopped_at=<behavior>:<step>` is surfaced (FR-001/FR-002).
/// - `zfa tdd verify --feature <f> --project <dir>` — exit 0 AND
///   `mutation: gate=pass` means success; every other gate label is
///   surfaced, never absorbed (FR-004).
///
/// The entrypoint is the `--zfa-bin` override when given (a `.dart`
/// entrypoint runs through `dart`; anything else — a compiled executable
/// or a scripted fake — executes directly), else the package root's
/// `bin/zfa.dart`. A missing summary line or a spawn failure is a
/// `runner-error` misfire, never a silent success and never a crash
/// (FR-011).
library;

import 'dart:io';

import 'step_runner.dart';

/// Which per-feature step the runner spawns.
enum CorpusStep { run, verify }

/// The spawner hook (injectable for fast-tier tests, mirroring
/// `StepSpawner`).
typedef CorpusSpawner =
    Future<ProcessResult> Function(
      List<String> command,
      String workingDirectory,
    );

/// One spawned step's machine-readable outcome.
class CorpusStepResult {
  const CorpusStepResult({
    required this.step,
    required this.exitCode,
    required this.outcome,
    required this.success,
    required this.output,
    this.stoppedAt,
  });

  final CorpusStep step;
  final int exitCode;

  /// The parsed machine token: run's `result=` value or verify's `gate=`
  /// value; `runner-error` for spawn failures and missing summary lines.
  final String outcome;

  /// Success per the step's contract: exit 0 AND the agreed token.
  final bool success;

  /// Combined stdout + stderr (for failure reports).
  final String output;

  /// Run's `stopped_at=<behavior>:<step>` when present (the ledger's
  /// behavior/step detail).
  final String? stoppedAt;

  @override
  String toString() =>
      'CorpusStepResult(${step.name}, exit: $exitCode, outcome: $outcome, '
      'success: $success)';
}

class CorpusStepRunner {
  CorpusStepRunner({
    this.zfaBin,
    CorpusSpawner? spawner,
    Future<String> Function()? entryResolver,
  }) : _spawner = spawner ?? _defaultSpawner,
       _entryResolver = entryResolver ?? StepRunner.defaultZfaBin;

  /// Explicit entrypoint override (`--zfa-bin`); null resolves the
  /// package's `bin/zfa.dart` via [StepRunner.defaultZfaBin].
  final String? zfaBin;

  final CorpusSpawner _spawner;
  final Future<String> Function() _entryResolver;

  String? _resolvedEntry;

  /// Spawn `zfa tdd run <feature> --project <projectRoot>`.
  Future<CorpusStepResult> runFeature({
    required String feature,
    required String projectRoot,
  }) async {
    final argv = ['tdd', 'run', feature, '--project', projectRoot];
    return _spawn(
      step: CorpusStep.run,
      argv: argv,
      projectRoot: projectRoot,
      summaryPrefix: 'run',
      successToken: 'complete',
      tokenKey: 'result',
    );
  }

  /// Spawn `zfa tdd verify --feature <feature> --project <projectRoot>`.
  Future<CorpusStepResult> verifyFeature({
    required String feature,
    required String projectRoot,
  }) async {
    final argv = [
      'tdd',
      'verify',
      '--feature',
      feature,
      '--project',
      projectRoot,
    ];
    return _spawn(
      step: CorpusStep.verify,
      argv: argv,
      projectRoot: projectRoot,
      summaryPrefix: 'mutation',
      successToken: 'pass',
      tokenKey: 'gate',
    );
  }

  /// Spawn [argv] through the resolved entrypoint and map the result onto
  /// the step's contract: success = exit 0 AND the machine token agreeing.
  Future<CorpusStepResult> _spawn({
    required CorpusStep step,
    required List<String> argv,
    required String projectRoot,
    required String summaryPrefix,
    required String successToken,
    required String tokenKey,
  }) async {
    final String entry;
    try {
      entry = _resolvedEntry ??= zfaBin ?? await _resolveDefault();
    } on Object catch (e) {
      return _runnerError(step, 'entrypoint resolution failed: $e');
    }
    final command = [
      ...(entry.endsWith('.dart') ? ['dart', entry] : [entry]),
      ...argv,
    ];

    final ProcessResult process;
    try {
      process = await _spawner(command, projectRoot);
    } on ProcessException catch (e) {
      return _runnerError(
        step,
        'spawn failed for ${command.first}: ${e.message}',
      );
    } on IOException catch (e) {
      return _runnerError(step, 'spawn failed: $e');
    }

    final stdoutText = process.stdout.toString();
    final stderrText = process.stderr.toString();
    final output = stderrText.isEmpty ? stdoutText : '$stdoutText\n$stderrText';
    final kv = _parseSummaryLine(summaryPrefix, stdoutText);
    if (kv == null) {
      // No machine line: the contract is unfulfilled — a misfire, never
      // a silent success (FR-011).
      return CorpusStepResult(
        step: step,
        exitCode: process.exitCode,
        outcome: 'runner-error',
        success: false,
        output: output,
      );
    }
    final outcome = kv[tokenKey] ?? 'runner-error';
    return CorpusStepResult(
      step: step,
      exitCode: process.exitCode,
      outcome: outcome,
      success: process.exitCode == 0 && outcome == successToken,
      output: output,
      stoppedAt: kv['stopped_at'],
    );
  }

  CorpusStepResult _runnerError(CorpusStep step, String message) =>
      CorpusStepResult(
        step: step,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: message,
      );

  Future<String> _resolveDefault() async {
    // The corpus spawns the same entrypoint the run driver spawns
    // (spec 049's resolution rule, reused verbatim).
    return _entryResolver();
  }

  /// The last `<prefix>: key=value …` line in [stdout], parsed into a map —
  /// the step commands' machine contract (mirrors StepRunner).
  static Map<String, String>? _parseSummaryLine(String prefix, String stdout) {
    Map<String, String>? last;
    for (final line in stdout.split('\n')) {
      if (!line.startsWith('$prefix: ')) continue;
      final fields = <String, String>{};
      for (final match in RegExp(
        r'(\w+)=([^\s]+)',
      ).allMatches(line.substring(prefix.length + 2))) {
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
