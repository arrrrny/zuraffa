/// Per-command subprocess deadlines + the timed-spawn primitive (bug #742).
///
/// Bug #742: none of the TDD subsystem's `Process.run` invocations passed a
/// timeout, so a hanging `dart test` / `zfa build` / `zfa tdd func` child
/// made the runner hang forever (`zfa tdd make U4` never returned). This
/// library gives every TDD subprocess invocation a hard deadline:
///
///   1. [TddTimeouts] — the per-command defaults, generous by design (a
///      timeout that is too short causes spurious failures on slow CI
///      machines; the assessment's remediation names 10 min for a full
///      suite and 2 min for a single test), overridable by the
///      `--timeout <minutes>` flag on the spawning commands.
///   2. [runTimed] — the timed-spawn primitive every TDD call site uses in
///      place of bare `Process.run`. When the child outlives the deadline
///      it is killed (SIGKILL on POSIX, TerminateProcess on Windows), the
///      output captured so far is preserved, and a
///      [ProcessTimeoutException] is thrown so the call site can map the
///      outcome to its runnerError/timeout class and print a clear message
///      naming the behavior, step, and command.
///
/// Note: Dart's `Process.run` has NO timeout parameter (checked SDK
/// 3.13.x), so the deadline is enforced here with `Process.start` + a
/// raced `exitCode.timeout` + kill — the child is really killed, not
/// merely abandoned.
library;

import 'dart:async';
import 'dart:io';

/// Deadline configuration for every TDD subprocess invocation (bug #742).
class TddTimeouts {
  const TddTimeouts({
    this.singleTest = defaultSingleTest,
    this.suite = defaultSuite,
    this.pipelineStep = defaultPipelineStep,
    this.stepProcess = defaultStepProcess,
    this.refactorPass = defaultRefactorPass,
    this.mutationPreflight = defaultMutationPreflight,
    this.mutationRun = defaultMutationRun,
    this.probe = defaultProbe,
  });

  /// A single target test (`zfa tdd verify-red`, the make drift check /
  /// post-generation re-run).
  static const defaultSingleTest = Duration(minutes: 2);

  /// The full suite (make baseline + guard, verify-red re-certification).
  static const defaultSuite = Duration(minutes: 10);

  /// One generation pipeline step (`zfa entity create` / `zfa make` /
  /// `zfa build`).
  static const defaultPipelineStep = Duration(minutes: 10);

  /// One driver/corpus step process (`zfa tdd gen|verify-red|make|refactor`
  /// / `zfa tdd run|verify` spawned by the driver or the corpus harness).
  static const defaultStepProcess = Duration(minutes: 10);

  /// One refactor pass (build / format / fix).
  static const defaultRefactorPass = Duration(minutes: 10);

  /// The mutation audit's green-suite preflight (`dart test <scope>`).
  static const defaultMutationPreflight = Duration(minutes: 10);

  /// The mutation run itself (`dart run mutation_test`) — the slowest TDD
  /// child by design (one test execution per mutant).
  static const defaultMutationRun = Duration(minutes: 30);

  /// Tool availability probes (`dart --version`).
  static const defaultProbe = Duration(seconds: 30);

  final Duration singleTest;
  final Duration suite;
  final Duration pipelineStep;
  final Duration stepProcess;
  final Duration refactorPass;
  final Duration mutationPreflight;
  final Duration mutationRun;
  final Duration probe;

  /// The `--timeout <minutes>` override: replaces every per-command default
  /// with one uniform deadline for all subprocesses the command spawns.
  factory TddTimeouts.uniform(Duration deadline) => TddTimeouts(
    singleTest: deadline,
    suite: deadline,
    pipelineStep: deadline,
    stepProcess: deadline,
    refactorPass: deadline,
    mutationPreflight: deadline,
    mutationRun: deadline,
    probe: deadline,
  );
}

/// Parses the `--timeout <minutes>` flag value (bug #742).
///
/// `null`/empty → `null` (the command's per-command defaults apply).
/// Fractions are allowed (`0.5` = 30 s). Anything else that is not a
/// positive number of minutes throws [TddTimeoutFormatException] so the
/// command can reject it non-zero instead of guessing.
Duration? parseTddTimeoutMinutes(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final minutes = double.tryParse(raw);
  if (minutes == null || minutes <= 0) {
    throw TddTimeoutFormatException(raw);
  }
  return Duration(
    microseconds: (minutes * Duration.microsecondsPerMinute).round(),
  );
}

/// Thrown when the `--timeout` flag value is not a positive number of
/// minutes.
class TddTimeoutFormatException implements Exception {
  TddTimeoutFormatException(this.raw);

  /// The invalid flag value as given.
  final String raw;

  String get message =>
      'invalid --timeout "$raw": pass a positive number of minutes '
      '(fractions allowed, e.g. 0.5 for 30 seconds).';

  @override
  String toString() => message;
}

/// Thrown by [runTimed] when the child outlives [timeout] (bug #742).
///
/// The child has already been killed (SIGKILL on POSIX, TerminateProcess on
/// Windows) and reaped when this is thrown; [output] carries whatever it
/// wrote before the kill so the failure report stays actionable.
class ProcessTimeoutException implements Exception {
  ProcessTimeoutException({
    required this.executable,
    required this.arguments,
    required this.timeout,
    required this.workingDirectory,
    required this.output,
  });

  final String executable;
  final List<String> arguments;

  /// The deadline that fired.
  final Duration timeout;

  /// The working directory the child ran in, when known.
  final String? workingDirectory;

  /// stdout + stderr captured before the kill.
  final String output;

  /// The command line as it was invoked (post-resolution).
  String get commandDisplay => [executable, ...arguments].join(' ');

  @override
  String toString() {
    final buf = StringBuffer()
      ..write(
        'Subprocess TIMED OUT after ${formatTddTimeout(timeout)} and was '
        'killed (SIGKILL): `$commandDisplay`',
      );
    if (workingDirectory != null && workingDirectory!.isNotEmpty) {
      buf.write(' (working directory: $workingDirectory)');
    }
    final captured = output.trim();
    if (captured.isNotEmpty) {
      final lines = captured.split('\n');
      final tail = lines.length > 10
          ? lines.sublist(lines.length - 10).join('\n')
          : captured;
      buf
        ..writeln()
        ..write('   captured output before the kill (tail):\n   $tail');
    }
    return buf.toString();
  }
}

/// Human-readable duration for timeout messages: `45s`, `2m00s`, `10m00s`.
String formatTddTimeout(Duration d) {
  if (d.inMinutes == 0) return '${d.inSeconds}s';
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}m${seconds}s';
}

/// Runs [executable] with [arguments] under a hard [timeout] (bug #742).
///
/// Drop-in replacement for `Process.run` at every TDD spawn site:
///
///   * spawn failure throws [ProcessException] exactly like `Process.run`;
///   * a child that finishes within [timeout] returns the same
///     [ProcessResult] `Process.run` would have returned (systemEncoding
///     decoding, combined-capture semantics preserved by the caller);
///   * a child that outlives [timeout] is KILLED (SIGKILL), reaped, and a
///     [ProcessTimeoutException] carrying the output captured so far is
///     thrown — no TDD subprocess may await a child indefinitely.
Future<ProcessResult> runTimed(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell = false,
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: runInShell,
  );
  final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
  final stderrFuture = process.stderr.transform(systemEncoding.decoder).join();
  var killed = false;
  int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    killed = true;
    // Kill (SIGKILL on POSIX) and reap so no zombie survives the deadline.
    process.kill(ProcessSignal.sigkill);
    exitCode = await process.exitCode;
  }
  final stdoutText = await stdoutFuture;
  final stderrText = await stderrFuture;
  if (killed) {
    throw ProcessTimeoutException(
      executable: executable,
      arguments: arguments,
      timeout: timeout,
      workingDirectory: workingDirectory,
      output: '$stdoutText$stderrText',
    );
  }
  return ProcessResult(process.pid, exitCode, stdoutText, stderrText);
}
