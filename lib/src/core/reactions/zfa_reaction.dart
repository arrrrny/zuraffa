import '../failure.dart';

/// A single typed reaction step in a [ZfaReactionBus] choreography.
///
/// A reaction is registered for a pair of runtime types — the use case input
/// [I] and the use case result [O] — and a `reactionId` that names the causal
/// hop (it becomes the child span's operation). When a use case of input [I]
/// produces a result of [O], the reaction's [toIntent] maps that pair to the
/// next intent, which the bus then dispatches.
///
/// A reaction registered through `onFailure` carries [onFailure] = `true` and
/// its [O] is the failure type ([AppFailure]); its [toIntent] maps a failure to
/// a recovery intent.
///
/// Type matching is captured at construction: [matches] / [resolve] close over
/// the concrete [I] and [O] the reaction was created with, so the bus can store
/// reactions type-erased and still match them by runtime type.
class ZfaReaction<I extends Object, O extends Object, N extends Object> {
  /// Create a typed reaction.
  ZfaReaction({
    required this.reactionId,
    required this.toIntent,
    this.onFailure = false,
  });

  /// The causal name of this hop; used as the child span's operation.
  final String reactionId;

  /// Maps the matched `(intent, result)` pair to the next intent to dispatch.
  final N Function(I intent, O result) toIntent;

  /// Whether this reaction fires on failure (`true`) or success (`false`).
  final bool onFailure;

  /// Whether this reaction handles the given `(intent, result)` runtime types.
  ///
  /// The check uses the reaction's own reified type arguments, so it still
  /// matches correctly when the reaction is stored type-erased by the bus.
  bool matches(Object intent, Object result) => intent is I && result is O;

  /// Compute the next intent for a matched `(intent, result)` pair.
  Object resolve(Object intent, Object result) =>
      toIntent(intent as I, result as O);
}
