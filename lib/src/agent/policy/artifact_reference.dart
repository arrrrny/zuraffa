import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// A compact reference to an externally stored large result (FR-010).
class ArtifactReference {
  ArtifactReference({
    required this.uri,
    required this.size,
    required this.sha256,
    this.truncated = false,
  });

  final String uri;
  final int size;
  final String sha256;
  final bool truncated;

  Map<String, Object?> toJson() => <String, Object?>{
        '__artifact__': true,
        'uri': uri,
        'size': size,
        'sha256': sha256,
        'truncated': truncated,
      };

  @override
  String toString() => 'ArtifactReference($uri, size=$size)';

  /// Computes the SHA-256 hash of [payload].
  ///
  /// Falls back to `toString()` when [payload] is not JSON-encodable, so the
  /// oversized-result guard can never throw on an arbitrary tool payload
  /// (FR-010 stability: an oversized result must not crash the tool call).
  static String hashOf(Object? payload) {
    final String payloadStr;
    if (payload is String) {
      payloadStr = payload;
    } else {
      payloadStr = _jsonEncodeOrFallback(payload);
    }
    return crypto.sha256.convert(utf8.encode(payloadStr)).toString();
  }

  /// Encodes [payload] as JSON, or falls back to [Object.toString] when it is
  /// not JSON-encodable (avoids [JsonUnsupportedObjectError]).
  static String _jsonEncodeOrFallback(Object? payload) {
    try {
      return jsonEncode(payload);
    } on JsonUnsupportedObjectError {
      return payload.toString();
    }
  }
}
