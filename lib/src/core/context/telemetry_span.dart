/// A causal telemetry span for the v8 chord runtime.
///
/// A [TelemetrySpan] is one timed operation inside a causal tree: a span may
/// name a [parent], and every child span registers itself on its parent's
/// [children]. That parent/child wiring is the causal chain the runtime
/// exports — a child never starts without a link back to the operation that
/// caused it.
///
/// A span records its [operation] name, free-form string [attributes], its
/// [duration] once ended, and whether it has [isEnded]. [end] is idempotent:
/// the first end fixes the duration.
///
/// ## Chord invariant
///
/// A span carries timing and causal metadata only. Repositories, database
/// handles and HTTP clients never live here or in [ZfaContext].
class TelemetrySpan {
  TelemetrySpan({
    required this.operation,
    this.parent,
    Map<String, String> attributes = const {},
    DateTime? startTime,
  }) : attributes = Map<String, String>.of(attributes),
       _startTime = startTime ?? DateTime.now() {
    parent?.children.add(this);
  }

  /// The operation name this span measures.
  final String operation;

  /// The span that caused this one, or `null` for a root span.
  final TelemetrySpan? parent;

  /// Child spans linked to this one, in creation order.
  final List<TelemetrySpan> children = [];

  /// Mutable string attributes describing this span.
  final Map<String, String> attributes;

  final DateTime _startTime;
  DateTime? _endTime;
  bool _ended = false;

  /// Whether [end] has been called.
  bool get isEnded => _ended;

  /// The wall-clock duration, or `null` while the span is still open.
  Duration? get duration => _endTime?.difference(_startTime);

  /// Attach or replace an attribute.
  void setAttribute(String key, String value) {
    attributes[key] = value;
  }

  /// Close the span, fixing its [duration]. Idempotent.
  void end() {
    if (_ended) return;
    _ended = true;
    _endTime = DateTime.now();
  }

  @override
  String toString() =>
      'TelemetrySpan($operation, parent: ${parent?.operation}, '
      'ended: $_ended)';
}
