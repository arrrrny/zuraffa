import 'dart:async';

import '../failure.dart';
import '../result.dart';
import 'zfa_middleware.dart';

/// The outcome of evaluating one [ZfaPolicyRule] against an intent.
enum ZfaPolicyDecision {
  /// The rule permits the intent to proceed to [ZfaMiddleware.intercept]'s
  /// `next`.
  allow,

  /// The rule blocks the intent; the gate short-circuits with a
  /// [PolicyDeniedFailure].
  deny,
}

/// A typed policy rule evaluated by [PolicyGateMiddleware] before `next`.
///
/// A rule names itself with [id] and decides [evaluate] the intent under the
/// current [ZfaMiddlewareContext]. The built-in gate runs every rule in order
/// and denies the intent at the first [ZfaPolicyDecision.deny].
abstract class ZfaPolicyRule<I> {
  /// A stable identifier for this rule, surfaced on a denial.
  String get id;

  /// Decide whether [intent] may proceed under [ctx].
  ZfaPolicyDecision evaluate(I intent, ZfaMiddlewareContext ctx);
}

/// Built-in middleware that evaluates typed [ZfaPolicyRule]s before `next`
/// (ZFA-006).
///
/// The rules run in declaration order. The first rule that returns
/// [ZfaPolicyDecision.deny] short-circuits the pipeline with a
/// [PolicyDeniedFailure] whose [PolicyDeniedFailure.reason] is the rule's
/// [ZfaPolicyRule.id]; `next` is never invoked. When every rule allows, the
/// intent flows on unchanged.
class PolicyGateMiddleware<I, O> implements ZfaMiddleware<I, O> {
  /// Creates a gate over [rules], evaluated in order.
  const PolicyGateMiddleware({required this.rules});

  /// The rules this gate evaluates, in order.
  final List<ZfaPolicyRule<I>> rules;

  @override
  Future<Result<O, AppFailure>> intercept(
    I intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<I, O> next,
  ) async {
    for (final rule in rules) {
      if (rule.evaluate(intent, ctx) == ZfaPolicyDecision.deny) {
        return Result.failure(
          AppFailure.policyDenied(
            message: 'Policy denied by rule "${rule.id}"',
            reason: rule.id,
          ),
        );
      }
    }
    return next(intent, ctx);
  }
}
