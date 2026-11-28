import '../context/cancellation_token.dart';
import '../context/zfa_context.dart';
import '../failure.dart';
import '../result.dart';
import 'zfa_reaction.dart';

/// Executes a single intent under a [ZfaContext] and returns its result.
///
/// The bus is decoupled from concrete use cases: the caller supplies a runner
/// that knows how to execute any intent (typically a small `switch` that
/// dispatches to the matching use case). This keeps the choreography pure-Dart
/// and free of the strict-Chord rule's banned I/O handles.
typedef ReactionRunner =
    Future<Result<Object?, AppFailure>> Function(
      Object intent,
      ZfaContext context,
    );

/// A typed, decoupled reaction bus for use case choreography.
///
/// A bus chains use cases by registering typed reactions ([onSuccess] /
/// [onFailure]). [run] executes an initial intent, and whenever a step's
/// runtime `(input, output)` types match a registered reaction, the bus maps to
/// the next intent, spawns a child [ZfaContext] via
/// [ZfaContext.childSpan] (incrementing `cascadeDepth` by one and linking the
/// causal span and cancellation token), and dispatches it. The chain stops when
/// no reaction matches, and a circular chain is halted once it crosses
/// [maxCascadeDepth] with a [PolicyDeniedFailure] carrying
/// `reason: 'cascadeDepth'`.
///
/// ## Example
///
/// ```dart
/// final bus = ZfaReactionBus();
/// bus.onSuccess<ImportOrderIntent, Order, CheckPriceIntent>(
///   reactionId: 'order.import -> price.check',
///   toIntent: (_, order) => CheckPriceIntent(order.productId),
/// );
/// final result = await bus.run(
///   const ImportOrderIntent('order-1'),
///   runner: dispatchUseCase,
///   context: ZfaContext.root(),
/// );
/// ```
class ZfaReactionBus {
  /// Create a bus with the given loop guard (default `8`).
  ZfaReactionBus({this.maxCascadeDepth = 8});

  /// The maximum [ZfaContext.cascadeDepth] before a cascade is halted.
  ///
  /// This is the bus's own structural loop guard (default `8`). It is
  /// independent of [ZfaContext.maxCascadeDepth] (`64`) and
  /// [ZfaContext.isCascadeLimitExceeded], which the bus deliberately does not
  /// consult — tuning the context's cascade limit does not move this guard.
  final int maxCascadeDepth;

  final List<ZfaReaction<dynamic, dynamic, dynamic>> _reactions = [];

  /// Register a reaction that fires when a use case of input [I] succeeds with
  /// output [O], mapping `(intent, output)` to the next intent.
  ZfaReaction<I, O, N>
  onSuccess<I extends Object, O extends Object, N extends Object>({
    required String reactionId,
    required N Function(I intent, O output) toIntent,
  }) {
    final reaction = ZfaReaction<I, O, N>(
      reactionId: reactionId,
      toIntent: toIntent,
    );
    _reactions.add(reaction);
    return reaction;
  }

  /// Register a reaction that fires when a use case of input [I] fails,
  /// mapping `(intent, failure)` to a recovery intent.
  ZfaReaction<I, AppFailure, N> onFailure<I extends Object, N extends Object>({
    required String reactionId,
    required N Function(I intent, AppFailure failure) toIntent,
  }) {
    final reaction = ZfaReaction<I, AppFailure, N>(
      reactionId: reactionId,
      toIntent: toIntent,
      onFailure: true,
    );
    _reactions.add(reaction);
    return reaction;
  }

  /// Execute [intent] and follow the reaction chain to its terminal result.
  ///
  /// [runner] executes one intent under the supplied context. The returned
  /// result is the last step's result, or a [PolicyDeniedFailure] with
  /// `reason: 'cascadeDepth'` when the cascade crosses [maxCascadeDepth].
  /// An [AppFailure] (or a
  /// cancellation thrown by [ZfaContext.throwIfCancelled]) raised by the runner
  /// is also returned as a [Result.failure], so cancellation and loop-guard
  /// termination reach callers on the same channel.
  Future<Result<Object?, AppFailure>> run(
    Object intent, {
    required ReactionRunner runner,
    required ZfaContext context,
  }) async {
    final result = await _invokeRunner(runner, intent, context);
    return _advance(
      intent: intent,
      result: result,
      runner: runner,
      context: context,
    );
  }

  /// Invoke [runner] for one step, routing a thrown failure onto the same
  /// [Result.failure] channel used for returned failures and the loop guard.
  ///
  /// A runner following the idiomatic `ctx.throwIfCancelled()` pattern throws a
  /// [CancellationTokenException] instead of returning a [Result]; without this
  /// bridge that exception escapes [run] while every other termination is a
  /// [Result.failure].
  Future<Result<Object?, AppFailure>> _invokeRunner(
    ReactionRunner runner,
    Object intent,
    ZfaContext context,
  ) async {
    try {
      return await runner(intent, context);
    } on AppFailure catch (failure) {
      return Result.failure(failure);
    } on CancellationTokenException catch (e) {
      return Result.failure(AppFailure.cancelled(message: e.toString()));
    }
  }

  Future<Result<Object?, AppFailure>> _advance({
    required Object intent,
    required Result<Object?, AppFailure> result,
    required ReactionRunner runner,
    required ZfaContext context,
  }) async {
    final succeeded = result.isSuccess;
    final payload = succeeded ? result.getOrNull() : result.getFailureOrNull();
    final reaction = _find(intent, payload, succeeded);
    if (reaction == null) return result;

    final child = context.childSpan(
      operation: reaction.reactionId,
      cascadeIncrement: 1,
    );
    if (child.cascadeDepth > maxCascadeDepth) {
      return Result.failure(
        AppFailure.policyDenied(
          message: 'Operation denied by policy',
          reason: 'maxCascadeDepth',
        ),
      );
    }

    final nextIntent = reaction.resolve(intent, payload!);
    final nextResult = await _invokeRunner(runner, nextIntent, child);
    final advanced = await _advance(
      intent: nextIntent,
      result: nextResult,
      runner: runner,
      context: child,
    );
    // The child (and its descendants, absorbed during the recursive advance)
    // spent into their own ledgers. Roll the whole subtree's spend up so the
    // root context's ledger reflects the cost of the entire choreography.
    context.cost.absorb(child.cost);
    return advanced;
  }

  /// Find the first registered reaction matching the runtime `(intent,
  /// payload)` types and the success/failure polarity.
  ///
  /// Matching is first-match-wins: if two reactions are registered for the
  /// same `(I, O)` pair, only the first one registered ever fires; a later
  /// duplicate is silently ignored (no diagnostic is emitted). Register at
  /// most one reaction per type pair when distinct behaviour is expected.
  ZfaReaction<dynamic, dynamic, dynamic>? _find(
    Object intent,
    Object? payload,
    bool succeeded,
  ) {
    for (final reaction in _reactions) {
      if (reaction.onFailure == succeeded) continue;
      if (payload != null && reaction.matches(intent, payload)) return reaction;
    }
    return null;
  }
}
