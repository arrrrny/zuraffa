/// ZAP — Zuraffa Agent Protocol (spec 071, issue #809).
///
/// The open, versioned interop contract between ANY agent framework and
/// zuraffa: mission envelopes, evidence packets, checkpoint requests, and
/// receipt verification. MCP (#791) becomes ONE transport above this
/// contract; v0.1 ships NDJSON-over-stdio.
///
/// This library: [zap_protocol] (wire), [zap_schema] (draft-07 schemas),
/// [zap_validator] (structural validation), [zap_message] (typed layer),
/// [zap_chain] (receipt verification), [zap_golden] (golden examples),
/// [zap_executor] + [zap_host] (host), [zap_client] (reference client),
/// [zap_conformance] (conformance suite).
library;

import 'dart:convert';

/// The protocol version spoken by this implementation.
///
/// `0.1` is the v0 draft slice from issue #809; `1.0` is reserved for the
/// first stable release. The version rides every envelope as the `zap`
/// field — a mismatch is a `version` error, never a silent
/// misinterpretation.
const String zapProtocolVersion = '0.1';

/// The message types of the protocol.
///
/// The four core types are the contract; `error` is the auxiliary
/// rejection channel (host → agent only).
const List<String> zapCoreTypes = [
  'mission',
  'evidence',
  'checkpoint',
  'receipt',
];

/// All wire types (core + the auxiliary `error`).
const List<String> zapMessageTypes = [...zapCoreTypes, 'error'];

/// Types an agent may send to the host (the inbound direction).
const List<String> zapInboundTypes = ['mission', 'checkpoint'];

/// NDJSON envelope helpers for the ZAP wire protocol.
///
/// One JSON object per line, in and out — the same discipline as the
/// agent shell wire (#808). The host (`zfa zap serve`) reads request
/// envelopes from stdin and writes reply envelopes to stdout; this codec
/// is the single place lines are encoded/decoded.
abstract final class ZapProtocol {
  /// Encode [message] as a single NDJSON line (terminated with `\n`).
  static String encodeLine(Map<String, Object?> message) =>
      '${jsonEncode(message)}\n';

  /// Decode one NDJSON line into a message map.
  ///
  /// Throws [FormatException] on garbage input — the host converts that
  /// into a `schema` error envelope rather than dying.
  static Map<String, Object?> decodeLine(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      throw FormatException(
        'ZAP lines are JSON objects; got '
        '${decoded.runtimeType}',
      );
    }
    return decoded.cast<String, Object?>();
  }

  /// Convenience envelope builder: `zap`/`type`/`id`/`ts` + [fields].
  static Map<String, Object?> envelope(
    String type,
    String id,
    String ts,
    Map<String, Object?> fields,
  ) => <String, Object?>{
    'zap': zapProtocolVersion,
    'type': type,
    'id': id,
    'ts': ts,
    ...fields,
  };
}
