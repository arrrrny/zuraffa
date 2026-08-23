/// Recoverable, typed errors for the session plugin.
///
/// Every failure the session layer reports — an unknown preset on a strict
/// create, a malformed or unsupported serialized envelope, a duplicate
/// preset registration — surfaces as a [ZuraffaSessionException] so callers
/// can recover programmatically instead of crashing (spec edge cases).
library;

/// A typed, recoverable session-layer error.
class ZuraffaSessionException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const ZuraffaSessionException(this.code, this.message);

  /// The preset name referenced by the caller is not registered.
  factory ZuraffaSessionException.unknownPreset(String name) =>
      ZuraffaSessionException(
        'unknown_preset',
        'No session preset registered under "$name".',
      );

  /// A preset with the same name is already registered.
  factory ZuraffaSessionException.duplicatePreset(String name) =>
      ZuraffaSessionException(
        'duplicate_preset',
        'A session preset named "$name" is already registered.',
      );

  /// The serialized envelope cannot be parsed or its version is unsupported.
  factory ZuraffaSessionException.malformedEnvelope(String detail) =>
      ZuraffaSessionException(
        'malformed_envelope',
        'Invalid session payload: $detail',
      );

  @override
  String toString() => 'ZuraffaSessionException($code): $message';
}
