/// `VerdictEnvelope` — the uniform versioned JSON verdict every TDD
/// command emits when `--json` is passed (issue #964, VISION §3, §4, §5;
/// machine contract finished by issue #969).
///
/// **EPIC 1150 migration**: this type is now a thin adapter over the
/// ONE canonical fleet envelope, `zuraffa.verdict.v1`
/// (`core/verdict/verdict_envelope.dart`). The legacy `verdict.v1` shape
/// (`verdict`/`details`/`timestamp` keys, string exit labels) is
/// superseded — the emitted JSON is the canonical envelope:
///
/// ```json
/// {
///   "schema": "zuraffa.verdict.v1",
///   "command": "zfa tdd run",          // FULL invocation
///   "result": "ok|error|skipped|refused",
///   "exit_class": 0,                   // the INT exit code (SPEC 917)
///   "message": "human-readable summary",
///   "data": { "command-specific payload" },
///   "fix": "…",                        // only when there is one
///   "drifts": [],
///   "ts": "2026-09-05T18:30:00Z"
/// }
/// ```
///
/// Legacy-key preservation (nothing is lost, everything moved INSIDE
/// `data`):
///
///   * `verdict` (pass|fail|stopped|error) maps onto `result`
///     (pass→ok, fail→error, stopped→skipped, error→error) — the raw
///     legacy verdict name is also kept at `data.verdict`;
///   * the string exit label (`ok`, `fail`, `complete`, …) is kept at
///     `data.exit_label` — the canonical `exit_class` is the INT exit
///     code, derived from the outcome when a verb did not supply one;
///   * `feature`, `subject` (SPEC 1106) and `findings` (SPEC 1106) land
///     at `data.feature` / `data.subject` / `data.findings`;
///   * `details` merge into `data` verbatim (details keys win on
///     collision — they are the verb's own vocabulary);
///   * `timestamp` is `ts` now.
///
/// The envelope is the LAST stdout line as ONE line of JSON; existing
/// text output above it stays human-readable (so `zfa tdd <verb>`
/// without `--json` works exactly as it always did).
library;

import 'dart:convert';

import '../../../core/verdict/verdict_envelope.dart' as verdict;

/// The verdict categories the TDD verbs reason in. Superseded on the
/// wire by [verdict.VerdictResult] — this enum is the verb-side
/// vocabulary the commands already use; the mapping to the canonical
/// `result` happens in [VerdictEnvelope.toJsonLine].
///
/// EPIC 1150: `refused` is the verb-side home for "never ran as
/// invoked" (usage/grammar/policy) — it maps onto the canonical
/// `result: refused` (exit 2).
enum VerdictOutcome { pass, fail, stopped, error, refused }

/// The uniform versioned JSON verdict every TDD command emits when
/// `--json` is passed — now the canonical `zuraffa.verdict.v1` shape.
class VerdictEnvelope {
  VerdictEnvelope({
    required this.command,
    required this.outcome,
    this.commandPrefix = 'zfa tdd',
    this.exitCode,
    this.exitClass,
    this.message,
    this.fix,
    List<String>? drifts,
    Map<String, Object?>? details,
    this.feature,
    this.subject,
    this.findings,
    DateTime? timestamp,
  }) : drifts = drifts ?? const <String>[],
       details = details ?? <String, Object?>{},
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The TDD subcommand the envelope came from (e.g. `run`, `gen`,
  /// `corpus status`). Emitted as `$commandPrefix $command`.
  final String command;

  /// The command family prefix the FULL invocation is built from. TDD
  /// verbs keep the default `zfa tdd`; non-TDD consumers of this carrier
  /// (`zfa di verify`, `zfa datasource check`, `zfa dream`, the top-level
  /// `zfa corpus` family) pass `zfa` so the envelope names its true
  /// producer (EPIC 1150: `command` must be the FULL invocation).
  final String commandPrefix;

  /// The feature the command operated on, if any.
  final String? feature;

  /// The verdict category (verb-side vocabulary).
  final VerdictOutcome outcome;

  /// The int exit code the process will exit with (SPEC 917). Null
  /// derives it from [outcome]: pass→0, fail→1, stopped→2, error→1.
  final int? exitCode;

  /// The command's shipped exit-taxonomy label (`ok`, `fail`,
  /// `complete`, `stopped`, `runner-error`, ...). Preserved verbatim at
  /// `data.exit_label`; null falls back to a sensible default.
  final String? exitClass;

  /// The human-readable summary line. Null derives a terse one from the
  /// command and exit code.
  final String? message;

  /// The machine-actionable remediation (`--> fix:` content), when one
  /// exists.
  final String? fix;

  /// WHAT the verdict is about (SPEC 1106 verify-gate extension), e.g.
  /// `{kind: "di"}` or `{kind: "datasource", entity: "Product"}`. Null
  /// omits the key from `data` (tdd verbs never set it).
  final Map<String, Object?>? subject;

  /// Structured per-finding records (SPEC 1106 verify-gate extension),
  /// each `{kind, file, member, fix}`. Null omits the key from `data`
  /// (tdd verbs never set it).
  final List<Map<String, Object?>>? findings;

  /// Drift/diff findings the verdict is about (empty when none).
  final List<String> drifts;

  /// Command-specific key/value details (e.g. `created: 3`, `red: 1`).
  /// Merged into `data` verbatim.
  final Map<String, Object?> details;

  /// ISO 8601 UTC timestamp; injected in tests for determinism.
  final DateTime timestamp;

  /// The stable schema name; consumers grep for it. EPIC 1150: the
  /// canonical fleet schema — one shape for every `zfa` verb.
  static const String schema = verdict.VerdictEnvelope.schema;

  /// Maps the verb-side outcome onto the canonical result vocabulary.
  static verdict.VerdictResult canonicalResult(VerdictOutcome outcome) =>
      switch (outcome) {
        VerdictOutcome.pass => verdict.VerdictResult.ok,
        VerdictOutcome.fail => verdict.VerdictResult.error,
        VerdictOutcome.stopped => verdict.VerdictResult.skipped,
        VerdictOutcome.error => verdict.VerdictResult.error,
        VerdictOutcome.refused => verdict.VerdictResult.refused,
      };

  /// The int exit code for an outcome when the verb did not supply one
  /// (SPEC 917: 0 success, 1 failure, 2 usage/refusal).
  static int defaultExitCode(VerdictOutcome outcome) => switch (outcome) {
    VerdictOutcome.pass => verdict.ExitClass.success,
    VerdictOutcome.stopped => verdict.ExitClass.usage,
    VerdictOutcome.refused => verdict.ExitClass.usage,
    _ => verdict.ExitClass.failure,
  };

  /// The default exit label for an outcome when the command does not
  /// declare one (issue #969: the envelope always carried one; it now
  /// lives at `data.exit_label`).
  static String defaultExitLabel(VerdictOutcome outcome) =>
      outcome == VerdictOutcome.pass ? 'ok' : 'fail';

  /// The canonical JSON map (EPIC 1150). `data` merges the verb details
  /// with the legacy top-level keys so nothing is lost:
  /// `verdict`, `exit_label`, `feature?`, `subject?`, `findings?`.
  Map<String, Object?> toJson() {
    final data = <String, Object?>{...details};
    data.putIfAbsent('verdict', () => outcome.name);
    data.putIfAbsent(
      'exit_label',
      () => exitClass ?? defaultExitLabel(outcome),
    );
    if (feature != null && feature!.isNotEmpty) {
      data.putIfAbsent('feature', () => feature);
    }
    if (subject != null) data.putIfAbsent('subject', () => subject);
    if (findings != null) data.putIfAbsent('findings', () => findings);
    return verdict.VerdictEnvelope(
      command: '$commandPrefix $command',
      result: canonicalResult(outcome),
      exitCode: exitCode ?? defaultExitCode(outcome),
      message:
          message ??
          '$command: ${outcome.name} '
              '(exit ${exitCode ?? defaultExitCode(outcome)})',
      data: data,
      fix: fix,
      drifts: drifts,
      timestamp: timestamp,
    ).toJson();
  }

  /// The single-line JSON encoding. The single-line form (no indent) is
  /// the contract — the envelope is the LAST stdout line, and a
  /// multi-line pretty-print would break line-oriented consumers.
  String toJsonLine() {
    final encoded = jsonEncode(toJson());
    return encoded;
  }

  /// The convenience constructor commands use: builds and emits in one
  /// call. The envelope is the LAST stdout line.
  static void emit({
    required String command,
    required VerdictOutcome outcome,
    String commandPrefix = 'zfa tdd',
    int? exitCode,
    String? exitClass,
    String? message,
    String? fix,
    List<String> drifts = const <String>[],
    Map<String, Object?> details = const <String, Object?>{},
    String? feature,
    Map<String, Object?>? subject,
    List<Map<String, Object?>>? findings,
  }) {
    final envelope = VerdictEnvelope(
      command: command,
      outcome: outcome,
      commandPrefix: commandPrefix,
      exitCode: exitCode,
      exitClass: exitClass,
      message: message,
      fix: fix,
      drifts: drifts,
      details: Map<String, Object?>.from(details),
      feature: feature,
      subject: subject,
      findings: findings,
    );
    // ignore: avoid_print
    print(envelope.toJsonLine());
  }
}
