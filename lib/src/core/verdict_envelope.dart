/// `ZuraffaVerdictEnvelope` — the canonical versioned JSON verdict for
/// `--json` emitters (issue #1105, consumed by SPEC 1124).
///
/// Issue #1105 ratifies ONE envelope schema for the whole A+ fleet:
///
/// ```json
/// {
///   "schema": "zuraffa.verdict.v1",
///   "command": "zfa repository create",
///   "verdict": "pass | fail | skip | error",
///   "exit_class": 0 | 1 | 2 | 3 | 4,
///   "subject": {"kind": "repository", "entity": "Product"},
///   "findings": [{"side": "...", "kind": "...", "fix": "..."}],
///   "details": {"...": "plugin-specific extras live here — the only
///                       plugin-specific surface of the envelope"},
///   "timestamp": "2026-09-07T00:00:00.000Z"
/// }
/// ```
///
/// with `exit_class` matching the ratified zfa exit protocol
/// (`ExitProtocol`: 0 success, 1 failure, 2 usage, 3 drift, 4 conflict).
///
/// The envelope is the LAST stdout line, single-line (the contract every
/// existing emitter shares — a pretty-print would break line-oriented
/// consumers). Human output printed above it stays untouched, so the
/// no-`--json` channel is unchanged.
///
/// Naming note: the tdd plugin's `VerdictEnvelope`
/// (`lib/src/plugins/tdd/models/verdict_envelope.dart`) keeps its class
/// name and its `verdict.v1` schema string — migrating every emitter to
/// THIS canonical schema is issue #1105's own sweep, deliberately outside
/// SPEC 1124's one-PR scope (which only wires the repository create verb).
/// This class carries the fully-qualified schema name so the two can never
/// be confused by grep or by parser.
library;

import 'dart:convert';

/// The verdict categories the canonical envelope can carry (issue #1105:
/// `pass | fail | skip | error`).
enum VerdictStatus { pass, fail, skip, error }

/// The canonical `zuraffa.verdict.v1` envelope (issue #1105).
class ZuraffaVerdictEnvelope {
  ZuraffaVerdictEnvelope({
    required this.command,
    required this.status,
    required this.exitClass,
    this.subject,
    List<Map<String, Object?>>? findings,
    this.manifest,
    List<String>? drifts,
    Map<String, Object?>? details,
    DateTime? timestamp,
  }) : findings = findings ?? const <Map<String, Object?>>[],
       drifts = drifts ?? const <String>[],
       details = details ?? const <String, Object?>{},
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The single canonical schema identifier; consumers grep for it.
  static const String schema = 'zuraffa.verdict.v1';

  /// The canonical command the verdict is about (e.g. `zfa repository
  /// create`) — the invocation grammar form, not the argv echo.
  final String command;

  /// The verdict category.
  final VerdictStatus status;

  /// The exit protocol code this run exited with (`ExitProtocol`: 0
  /// success, 1 failure, 2 usage, 3 drift, 4 conflict).
  final int exitClass;

  /// WHAT the verdict is about, e.g. `{kind: 'repository', entity:
  /// 'Product'}`. Null omits the key from the JSON.
  final Map<String, Object?>? subject;

  /// Structured per-finding records (gate mismatches, refusals), each
  /// carrying the machine-actionable remediation under `fix`.
  final List<Map<String, Object?>> findings;

  /// The contract manifest binding, when the run wrote one:
  /// `{path, sha256, methods}`. Null omits the key — a failed gate
  /// writes no manifest and the envelope must not claim one.
  final Map<String, Object?>? manifest;

  /// Drift/diff findings the verdict is about (empty when none).
  final List<String> drifts;

  /// Plugin-specific extras (the only plugin-specific surface — issue
  /// #1105).
  final Map<String, Object?> details;

  /// ISO 8601 UTC timestamp; injectable in tests for determinism.
  final DateTime timestamp;

  /// The JSON encoding of this envelope as a map (stable key order).
  Map<String, Object?> toJson() => {
    'schema': schema,
    'command': command,
    'verdict': status.name,
    'exit_class': exitClass,
    if (subject != null) 'subject': subject,
    'findings': findings,
    if (manifest != null) 'manifest': manifest,
    'drifts': drifts,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  /// The single-line form — the LAST stdout line contract.
  String toJsonLine() => jsonEncode(toJson());

  /// The convenience constructor emitters use: builds and prints in one
  /// call. The envelope is the LAST stdout line.
  static void emit({
    required String command,
    required VerdictStatus status,
    required int exitClass,
    Map<String, Object?>? subject,
    List<Map<String, Object?>>? findings,
    Map<String, Object?>? manifest,
    List<String>? drifts,
    Map<String, Object?>? details,
  }) {
    // ignore: avoid_print
    print(
      ZuraffaVerdictEnvelope(
        command: command,
        status: status,
        exitClass: exitClass,
        subject: subject,
        findings: findings,
        manifest: manifest,
        drifts: drifts,
        details: details,
      ).toJsonLine(),
    );
  }
}
