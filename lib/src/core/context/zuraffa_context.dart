import 'dart:collection';

/// Lightweight correlation context carrier flowing from UI → UseCase → Data.
///
/// [ZuraffaContext] holds trace IDs, session tokens, and extensible metadata
/// without polluting every method signature.
///
/// When not used, the [noop] instance provides zero-cost overhead.
class ZuraffaContext {
  const ZuraffaContext({
    this.traceId,
    this.sessionToken,
    this.agentMutationId,
    Map<String, dynamic>? metadata,
  }) : _metadata = metadata;

  /// Zero-cost no-op context. Pass this when telemetry is not needed.
  static const ZuraffaContext noop = ZuraffaContext();

  final String? traceId;
  final String? sessionToken;
  final String? agentMutationId;
  final Map<String, dynamic>? _metadata;

  /// Immutable metadata lookup.
  dynamic metadata(String key) => _metadata?[key];

  /// Create a child context with additional metadata merged in.
  ZuraffaContext withMetadata(Map<String, dynamic> extra) {
    final merged = HashMap<String, dynamic>.from(_metadata ?? const {});
    merged.addAll(extra);
    return ZuraffaContext(
      traceId: traceId,
      sessionToken: sessionToken,
      agentMutationId: agentMutationId,
      metadata: merged,
    );
  }

  @override
  String toString() =>
      'ZuraffaContext(traceId: $traceId, sessionToken: $sessionToken, '
      'agentMutationId: $agentMutationId)';
}
