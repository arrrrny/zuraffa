/// `VerdictEnvelope` — the uniform versioned JSON verdict every TDD
/// command emits when `--json` is passed (issue #964, VISION §3, §4, §5).
///
/// The contract is:
///   - `schema` is exactly `"verdict.v1"` (a stable key agents grep for;
///     drift is a treaty violation, VISION §3);
///   - `command` is the leaf verb (`run`, `plan`, `gen`, `view`, ...);
///   - `verdict` is one of `pass | fail | stopped | error`;
///   - `details` carries every command-specific key/value the existing
///     `key=value` text summary produced (so consumers that switch
///     from text to JSON lose no information);
///   - `timestamp` is ISO 8601 UTC (consumers can order outputs).
///
/// The envelope is the LAST stdout line; existing text output above it
/// stays human-readable (so `zfa tdd <verb>` without `--json` works
/// exactly as it always did). The class is intentionally tiny — a
/// record-like model — so commands can emit it in a single line.
library;

import 'dart:convert';

/// The verdict categories the envelope can carry.
enum VerdictOutcome { pass, fail, stopped, error }

/// The uniform versioned JSON verdict every TDD command emits when
/// `--json` is passed.
class VerdictEnvelope {
  VerdictEnvelope({
    required this.command,
    required this.outcome,
    Map<String, Object?>? details,
    this.feature,
    DateTime? timestamp,
  }) : details = details ?? <String, Object?>{},
       timestamp = timestamp ?? DateTime.now().toUtc();

  /// The TDD subcommand the envelope came from (e.g. `run`, `gen`).
  final String command;

  /// The feature the command operated on, if any.
  final String? feature;

  /// The verdict category.
  final VerdictOutcome outcome;

  /// Command-specific key/value details (e.g. `created: 3`, `red: 1`).
  final Map<String, Object?> details;

  /// ISO 8601 UTC timestamp; injected in tests for determinism.
  final DateTime timestamp;

  /// The stable schema name; consumers grep for it.
  static const String schema = 'verdict.v1';

  /// The JSON encoding of this envelope. The single-line form (no
  /// indent) is the contract — the envelope is the LAST stdout line,
  /// and a multi-line pretty-print would break line-oriented consumers.
  String toJsonLine() {
    final map = <String, Object?>{
      'schema': schema,
      'command': command,
      if (feature != null && feature!.isNotEmpty) 'feature': feature,
      'verdict': outcome.name,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
    return jsonEncode(map);
  }

  /// The convenience constructor commands use: builds and emits in one
  /// call. The envelope is the LAST stdout line.
  static void emit({
    required String command,
    required VerdictOutcome outcome,
    Map<String, Object?> details = const <String, Object?>{},
    String? feature,
  }) {
    // ignore: avoid_print
    print(
      VerdictEnvelope(
        command: command,
        outcome: outcome,
        details: Map<String, Object?>.from(details),
        feature: feature,
      ).toJsonLine(),
    );
  }
}
