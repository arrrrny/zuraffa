import 'dart:async';

/// Lightweight correlation context carrier flowing from UI → UseCase → Data.
///
/// [ZuraffaContext] holds trace IDs, session tokens, and extensible metadata
/// without polluting every method signature.
///
/// ## Automatic Propagation
///
/// Context propagates implicitly via Dart Zones. At the UI entry point:
/// ```dart
/// ZuraffaContext.runWith(
///   const ZuraffaContext(traceId: 'abc-123'),
///   () => runApp(MyApp()),
/// );
/// ```
///
/// Any code downstream can access the current context via [current]:
/// ```dart
/// final ctx = ZuraffaContext.current; // returns active context or noop
/// ```
///
/// ## Zero-Cost No-Op
///
/// When no context zone is active, [current] returns [noop] — a const
/// singleton with all fields null. The compiler can inline this to a
/// single static field read.
///
/// ## Nested Scopes
///
/// Scopes can be nested. A child context inherits parent fields and can
/// override or extend metadata:
/// ```dart
/// final child = parent.withMetadata({'screen': 'checkout'});
/// ```
class ZuraffaContext {
  const ZuraffaContext({
    this.traceId,
    this.sessionToken,
    this.agentMutationId,
    Map<String, dynamic>? metadata,
  }) : _metadata = metadata;

  // ── Fields ──

  final String? traceId;
  final String? sessionToken;
  final String? agentMutationId;
  final Map<String, dynamic>? _metadata;

  // ── No-op singleton ──

  /// Zero-cost no-op context. Returned by [current] when no zone is active.
  static const ZuraffaContext noop = ZuraffaContext();

  // ── Zone key ──

  static final Object _zoneKey = Object();

  // ── Read API ──

  /// Look up metadata by key. Returns `null` if missing or if this is [noop].
  dynamic metadata(String key) => _metadata?[key];

  /// All metadata entries. Returns an empty unmodifiable map for [noop].
  Map<String, dynamic> get metadataMap =>
      _metadata != null ? Map.unmodifiable(_metadata) : const {};

  /// Whether this context carries any actionable data (not [noop]).
  bool get isActive =>
      traceId != null ||
      sessionToken != null ||
      agentMutationId != null ||
      (_metadata != null && _metadata.isNotEmpty);

  /// Whether this is the no-op singleton.
  bool get isNoop => identical(this, noop);

  // ── Scope API ──

  /// Create a child context with additional metadata merged in.
  ///
  /// Parent fields (traceId, sessionToken, agentMutationId) are inherited
  /// unless explicitly overridden.
  ZuraffaContext withMetadata(
    Map<String, dynamic> extra, {
    String? traceId,
    String? sessionToken,
    String? agentMutationId,
  }) {
    final merged = <String, dynamic>{};
    if (_metadata != null) merged.addAll(_metadata);
    merged.addAll(extra);
    return ZuraffaContext(
      traceId: traceId ?? this.traceId,
      sessionToken: sessionToken ?? this.sessionToken,
      agentMutationId: agentMutationId ?? this.agentMutationId,
      metadata: merged,
    );
  }

  /// Create a child context with a new trace ID (e.g. for a sub-operation).
  ZuraffaContext withTraceId(String newTraceId) =>
      withMetadata({}, traceId: newTraceId);

  /// Create a child context scoped to an AI agent mutation.
  ZuraffaContext withAgentMutation(String mutationId) =>
      withMetadata({}, agentMutationId: mutationId);

  // ── Zone API ──

  /// Run [body] inside a zone where [current] returns this context.
  ///
  /// This is the entry-point for automatic propagation. Any async work
  /// spawned within [body] inherits the zone and therefore the context.
  static T runWith<T>(ZuraffaContext context, T Function() body) {
    return runZoned(body, zoneValues: {_zoneKey: context});
  }

  /// Run [body] inside a zone where [current] returns this context.
  /// Async variant.
  static Future<T> runWithAsync<T>(
    ZuraffaContext context,
    Future<T> Function() body,
  ) {
    return runZoned(body, zoneValues: {_zoneKey: context});
  }

  /// The context active in the current zone, or [noop] if none.
  ///
  /// This is a single map lookup — O(1) and inlined by the compiler.
  static ZuraffaContext get current {
    final ctx = Zone.current[_zoneKey];
    return ctx is ZuraffaContext ? ctx : noop;
  }

  /// Whether a non-noop context is active in the current zone.
  static bool get hasActiveContext => current.isActive;

  // ── Utility ──

  /// Generate a fresh trace ID (UUID v4 style, without external deps).
  static String generateTraceId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode ^ now;
    return '${now.toRadixString(16)}-${random.toRadixString(16)}';
  }

  @override
  String toString() =>
      'ZuraffaContext(traceId: $traceId, '
      'sessionToken: ${sessionToken != null ? "***" : null}, '
      'agentMutationId: $agentMutationId, '
      'metadata: ${_metadata?.keys.toList()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZuraffaContext &&
          other.traceId == traceId &&
          other.sessionToken == sessionToken &&
          other.agentMutationId == agentMutationId);

  @override
  int get hashCode => Object.hash(traceId, sessionToken, agentMutationId);
}
