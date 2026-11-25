import 'dart:async';
import '../failure.dart';
import '../result.dart';
import 'zfa_middleware.dart';

/// Composes and executes a pipeline of [ZfaMiddleware].
class MiddlewarePipeline<I, O> {
  final List<ZfaMiddleware<I, O>> _middlewares = [];

  /// Add middleware to the pipeline.
  MiddlewarePipeline<I, O> use(ZfaMiddleware<I, O> middleware) {
    _middlewares.add(middleware);
    return this;
  }

  /// Execute the pipeline wrapping the final handler.
  Future<Result<O, AppFailure>> execute(
    I intent,
    ZfaContext ctx,
    NextUseCase<I, O> handler,
  ) async {
    // Build the onion from inside out
    NextUseCase<I, O> current = handler;

    for (final middleware in _middlewares.reversed) {
      final nextStep = current;
      current = (I intent, ZfaContext ctx) {
        return middleware.intercept(intent, ctx, nextStep);
      };
    }

    return current(intent, ctx);
  }
}
