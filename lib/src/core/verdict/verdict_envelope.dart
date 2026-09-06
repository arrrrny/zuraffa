/// `zuraffa.verdict.v1` — the ONE canonical `--json` envelope for the whole
/// `zfa` fleet (EPIC 1150, superseding #1105's divergent envelopes and the
/// per-scheme shapes that grew out of #1132 EPIC 1).
///
/// ## The problem it kills
///
/// Before this contract, every command family invented its own `--json`
/// shape (RED evidence recorded in
/// `test/commands/verdict_envelope_1150_test.dart`):
///
///   1. `zfa xray status --json`        → `{"enabled":…,"release_mode":…}`
///   2. `zfa tdd verdicts --json`       → `verdict.v1` (verdict/details/timestamp)
///   3. `zfa manifest` (json default)   → bare JSON array
///   4. `zfa manifest --verify --json`  → `manifest-verify.v1`
///   5. `zfa proof check --format=json` → `proof.v1`
///   6. `zfa doctor --format=json`      → `doctor.v1`
///   7. `zfa benchmark list --json`     → `{"scenarios":[…]}`
///   8. `zfa make --format=json`        → `{"success":…, plan, files, …}`
///
/// No single shape an agent can rely on. After this sweep, every `--json`
/// path emits exactly ONE envelope as the LAST stdout line:
///
/// ```json
/// {
///   "schema": "zuraffa.verdict.v1",
///   "command": "zfa tdd make",
///   "result": "ok|error|skipped|refused",
///   "exit_class": 0,
///   "message": "human-readable summary",
///   "data": { "command-specific payload": true },
///   "fix": "zfa make Foo --methods=bar",
///   "drifts": [],
///   "ts": "2026-09-05T18:30:00Z"
/// }
/// ```
///
/// Key contract points:
///
///   * `schema` is exactly `"zuraffa.verdict.v1"` — the stable key agents
///     grep for (VISION §3: drift is a treaty violation);
///   * `command` is the FULL invocation (`zfa <group> <verb>`), not just
///     the leaf verb, so a log line identifies its producer;
///   * `result` is one of `ok | error | skipped | refused` (error = the
///     operation ran and gave an honest negative verdict; refused = it
///     never ran as invoked — usage/grammar/gating);
///   * `exit_class` is the INT exit code the process will exit with (the
///     ratified SPEC 917 protocol: 0/1/2/3/4 — see `ExitProtocol`), so
///     the envelope and `exit "$?"` can never disagree;
///   * `message` is the human-readable one-liner (the same prose the text
///     mode would print);
///   * `data` is the command-specific payload — nothing is lost when a
///     consumer switches from a legacy shape to the envelope, because the
///     legacy keys move INSIDE `data`;
///   * `fix` is the machine-actionable remediation, present only when
///     there is something to fix (omitted otherwise);
///   * `drifts` lists receipt/contract digest mismatches (empty when none);
///   * `ts` is ISO-8601 UTC — consumers can order outputs.
///
/// The envelope is the LAST stdout line as a SINGLE line of JSON (no
/// pretty-print — line-oriented consumers parse stdout tail-first).
library;

import 'dart:convert';

/// The int `exit_class` values the envelope carries (SPEC 917 golden
/// table, mirrored from `ExitProtocol` so the envelope contract stays
/// self-contained and greppable from the schema doc).
abstract final class ExitClass {
  /// `0` — success / GREEN / complete.
  static const int success = 0;

  /// `1` — RED (honest, expected in-loop) / stopped / audit failure /
  /// runtime failure.
  static const int failure = 1;

  /// `2` — usage/grammar error: the operation could not run as invoked.
  static const int usage = 2;

  /// `3` — contract/spec drift.
  static const int drift = 3;

  /// `4` — state conflict.
  static const int conflict = 4;
}

/// The result categories the canonical envelope can carry
/// (`ok | error | skipped | refused`).
enum VerdictResult {
  /// The operation ran and achieved its goal.
  ok,

  /// The operation ran and gave an honest negative verdict (RED, gate
  /// failure, audit failure) — exit 1/3-class.
  error,

  /// The operation stopped early for an honest, expected reason (skip,
  /// nothing to do, dry-run short-circuit).
  skipped,

  /// The operation never ran as invoked — usage/grammar error or a
  /// policy refusal (exit 2/4-class).
  refused,
}

/// The canonical `zuraffa.verdict.v1` envelope. One type, one shape, one
/// parser for the whole fleet.
class VerdictEnvelope {
  VerdictEnvelope({
    required this.command,
    required this.result,
    this.exitCode = ExitClass.success,
    required this.message,
    Map<String, Object?>? data,
    this.fix,
    List<Object?>? drifts,
    DateTime? timestamp,
  }) : data = data ?? const <String, Object?>{},
       drifts = drifts ?? const <Object?>[],
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The stable schema name consumers grep for.
  static const String schema = 'zuraffa.verdict.v1';

  /// The FULL invocation that produced the envelope (e.g. `zfa tdd make`).
  final String command;

  /// The result category.
  final VerdictResult result;

  /// The int exit code the process will exit with (SPEC 917 protocol).
  final int exitCode;

  /// The human-readable one-line summary.
  final String message;

  /// The command-specific payload (legacy keys land here — nothing lost).
  final Map<String, Object?> data;

  /// The machine-actionable remediation, when there is one.
  final String? fix;

  /// Receipt/contract digest mismatches (empty when none).
  final List<Object?> drifts;

  /// ISO-8601 UTC instant; injected in tests for determinism.
  final DateTime timestamp;

  /// The canonical JSON map. Key order is the contract order — stable,
  /// diffable, and easy on humans reading raw logs.
  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'command': command,
    'result': result.name,
    'exit_class': exitCode,
    'message': message,
    'data': data,
    if (fix != null && fix!.isNotEmpty) 'fix': fix,
    'drifts': drifts,
    'ts': timestamp.toIso8601String(),
  };

  /// The single-line JSON encoding — the contract is ONE parseable line
  /// as the LAST stdout line (pretty-printing would break tail parsers).
  String toJsonLine() => jsonEncode(toJson());

  /// Builds the envelope for a successful run (`result: ok`).
  static VerdictEnvelope ok(
    String command,
    String message, {
    Map<String, Object?>? data,
    List<Object?>? drifts,
    DateTime? timestamp,
  }) => VerdictEnvelope(
    command: command,
    result: VerdictResult.ok,
    message: message,
    data: data,
    drifts: drifts,
    timestamp: timestamp,
  );
}

/// The convenience emitter the whole fleet routes its `--json` output
/// through: builds the canonical envelope, prints it as the LAST stdout
/// line, and returns the emitted line (commands that need to capture it
/// for verdict carriers can reuse it verbatim).
String emitVerdict({
  required String command,
  required VerdictResult result,
  int exitCode = ExitClass.success,
  required String message,
  Map<String, Object?>? data,
  String? fix,
  List<Object?>? drifts,
  DateTime? timestamp,
  void Function(String line)? printSink,
}) {
  final line = VerdictEnvelope(
    command: command,
    result: result,
    exitCode: exitCode,
    message: message,
    data: data,
    fix: fix,
    drifts: drifts,
    timestamp: timestamp,
  ).toJsonLine();
  final sink = printSink ?? (text) {
    // ignore: avoid_print
    print(text);
  };
  sink(line);
  return line;
}

/// Structural check that a decoded JSON document IS a canonical
/// `zuraffa.verdict.v1` envelope. Used by `zfa manifest --verify`'s
/// envelope-shape certification and by tests.
bool isVerdictEnvelope(Map<String, Object?> json) =>
    json['schema'] == VerdictEnvelope.schema &&
    json['command'] is String &&
    json['result'] is String &&
    const {'ok', 'error', 'skipped', 'refused'}.contains(json['result']) &&
    json['exit_class'] is int &&
    json['message'] is String &&
    json['data'] is Map &&
    json['drifts'] is List &&
    json['ts'] is String;
