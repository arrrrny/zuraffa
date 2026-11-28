import 'cancellation_token.dart';
import 'telemetry_span.dart';
import 'zfa_cost_ledger.dart';

/// An absolute point in time after which work should stop.
///
/// A [ZfaContext] carries an optional [Deadline]; [childSpan] can install a
/// fresh one from a `timeout`. A deadline is **advisory** — cooperative work
/// checks [isExpired] at its own checkpoints, the same way it checks
/// cancellation.
class Deadline {
  /// A deadline at a fixed instant.
  const Deadline(this.expiresAt);

  /// A deadline [duration] from now.
  factory Deadline.after(Duration duration) =>
      Deadline(DateTime.now().add(duration));

  /// The instant this deadline expires at.
  final DateTime expiresAt;

  /// Whether the deadline has passed.
  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  /// Time left before expiry (negative once expired).
  Duration get remaining => expiresAt.difference(DateTime.now());
}

/// The v8 chord-runtime context (`ctx`).
///
/// [ZfaContext] is the pure-Dart carrier that flows through a reaction: a
/// cooperative [CancellationToken], a causal [TelemetrySpan], a self-counted
/// [ZfaCostLedger], an [cascadeDepth] counter for reaction-loop safety, and an
/// optional [Deadline]. It is created at the root with [ZfaContext.root] (or
/// the non-cancelling [ZfaContext.background]) and extended with [childSpan].
///
/// ## Strict Chord rule
///
/// Repositories, database handles and HTTP clients **never** live in a
/// [ZfaContext]. The context carries coordination signals only; anything that
/// touches the outside world is passed explicitly to the operation that needs
/// it.
///
/// ## Reaction-loop safety
///
/// [cascadeDepth] counts how many reactive cascades deep this context is.
/// [childSpan] raises it by `cascadeIncrement` (default `0`), and
/// [isCascadeLimitExceeded] flags a context that has crossed
/// [maxCascadeDepth] so a runaway reaction can be stopped before it loops.
class ZfaContext {
  ZfaContext._({
    required this.cancellation,
    required this.span,
    required this.cost,
    required this.cascadeDepth,
    required this.deadline,
    required this.isBackground,
    required this.baggage,
  });

  /// A fresh root context with a live cancellation token, no span, a new cost
  /// ledger, depth `0` and no deadline.
  factory ZfaContext.root({
    CancellationToken? cancellation,
    Deadline? deadline,
    Map<String, String> baggage = const {},
  }) {
    return ZfaContext._(
      cancellation: cancellation ?? CancellationToken(),
      span: null,
      cost: ZfaCostLedger(),
      cascadeDepth: 0,
      deadline: deadline,
      isBackground: false,
      baggage: Map<String, String>.of(baggage),
    );
  }

  static final ZfaContext _background = ZfaContext._(
    cancellation: CancellationToken.system(),
    span: null,
    cost: ZfaCostLedger(),
    cascadeDepth: 0,
    deadline: null,
    isBackground: true,
    baggage: const {},
  );

  /// The non-cancelling system context.
  ///
  /// Its cancellation token is a [CancellationToken.system] and never cancels,
  /// so work run under it outlives any request scope. It is a stable singleton
  /// and is treated as immutable.
  static ZfaContext get background => _background;

  /// The maximum [cascadeDepth] before [isCascadeLimitExceeded] trips.
  static const int maxCascadeDepth = 64;

  /// Cooperative cancellation signal for this scope.
  final CancellationToken cancellation;

  /// The causal span for this scope, or `null` at the root.
  final TelemetrySpan? span;

  /// This scope's own cost ledger. A child's spend rolls up via
  /// [ZfaCostLedger.absorb].
  final ZfaCostLedger cost;

  /// How many reactive cascades deep this context is.
  final int cascadeDepth;

  /// The absolute expiry for this scope, or `null` when unbounded.
  final Deadline? deadline;

  /// Whether this is the [background] system context.
  final bool isBackground;

  /// Immutable key/value correlation carried across the causal chain.
  ///
  /// Baggage is the out-of-band companion to the typed [span] attributes:
  /// values here survive every [childSpan] hop (a child inherits this scope's
  /// baggage and may add or override its own keys). It is how a caller-stamped
  /// correlation id — e.g. a `sourceContractId` set by [ZfaController.dispatch]
  /// — reaches every use case and reaction in the cascade without being passed
  /// explicitly. Like the rest of the context it carries coordination metadata
  /// only, never I/O handles (the Strict Chord rule).
  final Map<String, String> baggage;

  /// Whether this context has crossed [maxCascadeDepth].
  bool get isCascadeLimitExceeded => cascadeDepth > maxCascadeDepth;

  /// Create a child scope with its own span and cost ledger.
  ///
  /// The child's cancellation token is linked to this one (cascading
  /// cancellation), its span names [parent] = this scope's span (the causal
  /// chain), and [cascadeIncrement] is added to [cascadeDepth]. A [timeout]
  /// installs a fresh [Deadline] on the child; without one the child inherits
  /// this scope's deadline. The child inherits this scope's [baggage] and
  /// merges [baggage] over it (new keys win).
  ZfaContext childSpan({
    required String operation,
    Duration? timeout,
    int cascadeIncrement = 0,
    Map<String, String> attributes = const {},
    Map<String, String> baggage = const {},
  }) {
    final childSpan = TelemetrySpan(
      operation: operation,
      parent: span,
      attributes: attributes,
    );
    return ZfaContext._(
      cancellation: cancellation.child(),
      span: childSpan,
      cost: ZfaCostLedger(),
      cascadeDepth: cascadeDepth + cascadeIncrement,
      deadline: timeout != null ? Deadline.after(timeout) : deadline,
      isBackground: false,
      baggage: {...this.baggage, ...baggage},
    );
  }

  /// Throw if this scope's cancellation has been requested.
  void throwIfCancelled() => cancellation.throwIfCancelled();

  @override
  String toString() =>
      'ZfaContext(depth: $cascadeDepth, span: ${span?.operation}, '
      'background: $isBackground)';
}
