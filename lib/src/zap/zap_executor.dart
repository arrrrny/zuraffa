/// ZAP step executors (spec 071, issue #809, FR-011, FR-016).
///
/// [SubprocessZapStepExecutor] runs a mission step as a REAL subprocess:
/// the command is whitespace-tokenized and executed WITHOUT a shell — no
/// interpolation, no pipes, no injection — with a per-step timeout (kill
/// → exit 124 by convention). [ZapStepRun.digestOf] fixes the certified
/// digest rule: sha256 over the FULL combined output (capping is a
/// preview applied later, never to the digest).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'zap_message.dart';

/// The exit code convention for a step killed by its timeout.
const int zapTimeoutExit = 124;

/// The result of executing one mission step.
class ZapStepRun {
  const ZapStepRun({
    required this.stepId,
    required this.phase,
    required this.command,
    required this.exit,
    required this.digest,
    required this.at,
    required this.durationMs,
    required this.output,
  });

  final String stepId;
  final String phase;
  final String command;
  final int exit;

  /// sha256 hex over the FULL captured output.
  final String digest;

  /// ISO-8601 UTC of completion.
  final String at;
  final int durationMs;
  final String output;

  /// The certified digest of [bytes] — one rule, one place.
  static String digestOf(List<int> bytes) => sha256.convert(bytes).toString();
}

/// Executes one mission step.
abstract class ZapStepExecutor {
  const ZapStepExecutor();

  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  });
}

/// The production executor: real subprocess, no shell.
class SubprocessZapStepExecutor extends ZapStepExecutor {
  const SubprocessZapStepExecutor();

  @override
  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    final tokens = step.command.trim().split(RegExp(r'\s+'));
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    final started = DateTime.now();
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    // Drain both streams to completion — the certified digest covers
    // the FULL output, so the last chunks must be decoded before the
    // digest is computed, even when the process exits first.
    final stdoutDrained = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDrained = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuffer.write)
        .asFuture<void>();

    var timedOut = false;
    int exit;
    final done = process.exitCode;
    try {
      exit = await done.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      // SIGTERM can be trapped — a step that ignores it would hang the
      // sequential serve loop forever. Escalate straight to SIGKILL.
      process.kill(ProcessSignal.sigkill);
      // Wait out the kill, then normalize to the timeout convention —
      // the signal's raw negative code is not part of the contract.
      await done;
      exit = zapTimeoutExit;
    }
    await stdoutDrained;
    await stderrDrained;

    final combined = '${stdoutBuffer.toString()}${stderrBuffer.toString()}';
    final output = timedOut
        ? 'ZAP: step ${step.id} timed out after ${timeout.inSeconds}s '
              'and was killed\n$combined'
        : combined;
    final at = DateTime.now().toUtc();

    return ZapStepRun(
      stepId: step.id,
      phase: step.phase,
      command: step.command,
      exit: exit,
      digest: ZapStepRun.digestOf(utf8.encode(combined)),
      at: at.toIso8601String(),
      durationMs: at.difference(started).inMilliseconds,
      output: output,
    );
  }
}

/// Deterministic executor for tests and the conformance suite.
class ScriptedZapStepExecutor extends ZapStepExecutor {
  ScriptedZapStepExecutor(this.handler);

  /// stepId → run result (or throw to simulate a broken executor).
  final Future<ZapStepRun> Function(MissionStep step) handler;

  final List<String> invoked = [];

  @override
  Future<ZapStepRun> run(
    MissionStep step, {
    required String workingDirectory,
    required Duration timeout,
  }) async {
    invoked.add(step.id);
    return handler(step);
  }
}

/// Builds a deterministic scripted run.
ZapStepRun zapScriptedRun(MissionStep step, int exit, String output) =>
    ZapStepRun(
      stepId: step.id,
      phase: step.phase,
      command: step.command,
      exit: exit,
      digest: ZapStepRun.digestOf(utf8.encode(output)),
      at: DateTime.now().toUtc().toIso8601String(),
      durationMs: 1,
      output: output,
    );
