import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// A single tool-call record in the mission trace (FR-007).
class ToolCallRecord {
  ToolCallRecord({
    required this.name,
    required this.argumentsHash,
    required this.cleartextArgs,
    required this.duration,
    required this.status,
    required this.tokenUsage,
    required this.provider,
  });

  final String name;

  /// Hash of the arguments (SHA-256 hex by default; FR-008).
  final String argumentsHash;

  /// Fields explicitly allowlisted to be recorded in cleartext (FR-008).
  /// All other fields are redacted from the trace.
  final Map<String, Object?> cleartextArgs;

  final Duration duration;
  final String status;
  final int tokenUsage;
  final String? provider;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'argumentsHash': argumentsHash,
        'cleartextArgs': cleartextArgs,
        'durationMs': duration.inMilliseconds,
        'status': status,
        'tokenUsage': tokenUsage,
        'provider': provider,
      };
}

/// The mission trace (FR-007).
class MissionTrace {
  MissionTrace({
    required this.missionId,
    required this.inputHash,
    required this.planSteps,
    required this.toolCallRecords,
    required this.duration,
    required this.status,
    required this.tokens,
    required this.provider,
    required this.outcome,
    this.schemaVersion = '1.0.0',
  });

  final String schemaVersion;
  final String missionId;
  final String inputHash;
  final List<String> planSteps;
  final List<ToolCallRecord> toolCallRecords;
  final Duration duration;
  final String status;
  final int tokens;
  final String? provider;
  final Object? outcome;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'missionId': missionId,
        'inputHash': inputHash,
        'planSteps': planSteps,
        'toolCalls': toolCallRecords.map((r) => r.toJson()).toList(),
        'durationMs': duration.inMilliseconds,
        'status': status,
        'tokens': tokens,
        'provider': provider,
        'outcome': outcome?.toString(),
      };
}

/// Hashes tool-call arguments (FR-008).
///
/// By default, every argument field is hashed. Fields listed in
/// [allowlist] are recorded in cleartext; all others are replaced with
/// a `__hashed__:<sha256-hex-prefix>` marker in [cleartextArgs].
class ArgumentHasher {
  ArgumentHasher({this.allowlist = const <String>{}});

  final Set<String> allowlist;

  /// Returns a tuple of (overall arguments hash, cleartext args map).
  ({String hash, Map<String, Object?> cleartext}) hash(
    Map<String, Object?> args,
  ) {
    final cleartext = <String, Object?>{};
    final builder = StringBuffer();
    final sortedKeys = args.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = args[key];
      final valueJson = jsonEncode(value);
      builder.writeln('$key=$valueJson');
      if (allowlist.contains(key)) {
        cleartext[key] = value;
      } else {
        final valueHash = crypto.sha256.convert(utf8.encode(valueJson)).toString();
        cleartext[key] = '__hashed__:${valueHash.substring(0, 16)}';
      }
    }
    final overallHash =
        crypto.sha256.convert(utf8.encode(builder.toString())).toString();
    return (hash: overallHash, cleartext: cleartext);
  }
}
