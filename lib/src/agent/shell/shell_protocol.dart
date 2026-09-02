import 'dart:convert';

/// NDJSON envelope helpers for the agent shell wire protocol (issue #808).
///
/// One JSON object per line, in and out. The daemon (`zfa agent shell`)
/// reads request envelopes from the connected agent's stdin and writes
/// response + event envelopes (including `budget.tick` / `budget.breach`)
/// to stdout — the NDJSON stream.
abstract final class ShellProtocol {
  /// Build an envelope from a typed map (copied defensively).
  static Map<String, Object?> encode(Map<String, Object?> message) =>
      <String, Object?>{...message};

  /// Encode [message] as a single NDJSON line (terminated with `\n`).
  static String encodeLine(Map<String, Object?> message) =>
      '${jsonEncode(message)}\n';

  /// Decode one NDJSON line into a message map.
  ///
  /// Throws [FormatException] on garbage input — the shell converts that
  /// into an `error` envelope rather than dying.
  static Map<String, Object?> decodeLine(String line) =>
      (jsonDecode(line) as Map).cast<String, Object?>();

  /// Convenience event builders used by the shell.
  static Map<String, Object?> event(
    String type, {
    String? agentId,
    String? missionId,
    Map<String, Object?>? extra,
  }) {
    final msg = <String, Object?>{'type': type};
    if (agentId != null) msg['agentId'] = agentId;
    if (missionId != null) msg['missionId'] = missionId;
    if (extra != null) msg.addAll(extra);
    return msg;
  }
}
