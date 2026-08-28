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
  static String hashOf(Object? payload) {
    final payloadStr =
        payload is String ? payload : jsonEncode(payload);
    return crypto.sha256.convert(utf8.encode(payloadStr)).toString();
  }
}
