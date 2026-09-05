/// The shared `--json` verdict-envelope runner (issue #969, T001).
///
/// Every `zfa tdd` subcommand routes its body through
/// [runWithVerdictEnvelope]. The wrapper:
///
///   * runs the command body verbatim when `--json` is absent — the
///     observable behavior is byte-identical (exceptions rethrow, the
///     runner prints them, no envelope appears);
///   * when `--json` IS set, emits ONE versioned verdict envelope
///     (`verdict.v1`) as the FINAL stdout line on every exit path —
///     normal returns, refusal returns, and thrown errors (the error is
///     printed first, then the envelope; the exit code is forced
///     non-zero so the envelope and the exit agree);
///   * reads the per-command specifics (feature, verdict override,
///     exit-class label, fix line, drifts, details) from the
///     [VerdictContext] the body populates while it runs.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../models/verdict_envelope.dart';

/// Mutable carrier a command body populates with its envelope fields.
///
/// Everything is optional: the wrapper derives sensible defaults from
/// the final exit code and the command's `--feature`/positional args.
class VerdictContext {
  /// The feature the command operated on (when the body knows it).
  String? feature;

  /// Verdict override — when null, derived from the exit code.
  VerdictOutcome? outcome;

  /// The command's shipped exit-taxonomy label (`complete`,
  /// `stopped`, `runner-error`, ...). Null falls back to `ok`/`fail`.
  String? exitClass;

  /// The machine-actionable remediation line, when the path has one.
  String? fix;

  /// Drift findings the verdict is about.
  final List<String> drifts = <String>[];

  /// Command-specific key/value details (mirrors the text summary).
  final Map<String, Object?> details = <String, Object?>{};

  /// Whether the envelope was already emitted by the body itself (a
  /// verb with legacy emit sites that could not be folded). The wrapper
  /// then stays silent — exactly one envelope, never two.
  bool emitted = false;
}

/// Extracts the `--json` flag from a command's parsed args.
bool tddJsonMode(Command<void> command) {
  final args = command.argResults;
  if (args == null) return false;
  try {
    return args['json'] as bool? ?? false;
  } catch (_) {
    return false; // verb does not declare --json (parent commands)
  }
}

/// Resolves the feature for the envelope: the body's explicit value
/// wins, then the `--feature` option, then the first positional for
/// verbs whose first positional IS a feature name.
String? tddResolveFeature(
  Command<void> command,
  VerdictContext ctx, {
  bool featureFromRest = false,
}) {
  if (ctx.feature != null && ctx.feature!.isNotEmpty) return ctx.feature;
  final args = command.argResults;
  if (args == null) return null;
  try {
    final flag = args['feature'] as String?;
    if (flag != null && flag.isNotEmpty) return flag;
  } catch (_) {
    // --feature not declared on this verb.
  }
  if (featureFromRest && args.rest.isNotEmpty) return args.rest.first;
  return null;
}

/// Runs [body] and emits the `verdict.v1` envelope as the final stdout
/// line when the command was invoked with `--json`.
///
/// [featureFromRest] marks verbs whose FIRST positional argument is the
/// feature name (plan, run, reset, doctor, replay) — the envelope's
/// `feature` then defaults to it when the body did not set one.
/// [commandOverride] names the FULL verb path for family subcommands
/// (`corpus status`, `referee gate`) so the envelope is unambiguous.
Future<void> runWithVerdictEnvelope(
  Command<void> command,
  VerdictContext ctx,
  Future<void> Function() body, {
  bool featureFromRest = false,
  String? commandOverride,
}) async {
  final jsonMode = tddJsonMode(command);
  Object? thrown;
  StackTrace? stack;
  try {
    await body();
  } catch (e, s) {
    thrown = e;
    stack = s;
    if (!jsonMode) rethrow; // flag absent: byte-identical legacy behavior
  } finally {
    if (jsonMode && !ctx.emitted) {
      if (thrown != null) {
        // Mirror the runner's own error line so the visible output is
        // not lost, then close with the envelope (the runner would
        // otherwise print AFTER the envelope and break the contract).
        // ignore: avoid_print
        print('❌ Error: $thrown');
      }
      final exitCodeValue = thrown != null && exitCode == 0 ? 1 : exitCode;
      final outcome = ctx.outcome ?? (exitCodeValue == 0
          ? VerdictOutcome.pass
          : exitCodeValue == 1
          ? VerdictOutcome.fail
          : VerdictOutcome.error);
      VerdictEnvelope.emit(
        command: commandOverride ?? command.name,
        outcome: outcome,
        exitClass: ctx.exitClass ??
            (thrown != null
                ? 'error'
                : exitCodeValue == 0
                ? 'ok'
                : 'fail'),
        fix: ctx.fix,
        drifts: ctx.drifts,
        details: ctx.details,
        feature: tddResolveFeature(
          command,
          ctx,
          featureFromRest: featureFromRest,
        ),
      );
      ctx.emitted = true;
    }
  }
  if (thrown != null) {
    if (jsonMode) {
      // JSON mode consumed the error (printed + enveloped above): force
      // the non-zero exit the runner's own catch would have produced.
      if (exitCode == 0) exitCode = thrown is UsageException ? 64 : 1;
      return;
    }
    // Flag absent: propagate untouched (legacy behavior).
    Error.throwWithStackTrace(thrown, stack!);
  }
}
