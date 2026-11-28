import 'dart:async';

import 'package:meta/meta.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart' show ZorphyIntentBase;

import '../cancel_token.dart';
import '../context/cancellation_token.dart';
import '../context/zfa_context.dart';
import '../failure.dart';
import '../middleware/middleware_pipeline.dart';
import '../middleware/zfa_middleware.dart';
import '../result.dart';

/// The v8 asynchronous use case archetype.
///
/// A [UseCase] is a single business operation that takes a typed
/// [ZorphyIntentBase] intent and a [ZfaContext], runs an optional composed
/// [ZfaMiddleware] chain around its [execute], and returns a
/// [Result] carrying either the output or an [AppFailure].
///
/// Cancellation is cooperative: [execute] (and any middleware) checks
/// [ZfaContext.throwIfCancelled] at its own checkpoints. A thrown
/// [CancellationTokenException] — or a legacy [CancelledException] — is
/// translated into a cancelled [AppFailure] rather than escaping the call.
///
/// ## Example
///
/// ```dart
/// class AddUseCase extends UseCase<AddIntent, int> {
///   AddUseCase({super.middleware});
///
///   @override
///   Future<Result<int, AppFailure>> execute(AddIntent intent, ZfaContext ctx) async {
///     ctx.throwIfCancelled();
///     return Result.success(intent.a + intent.b);
///   }
/// }
///
/// final result = await AddUseCase().call(const AddIntent(2, 3), ZfaContext.root());
/// ```
abstract class UseCase<I extends ZorphyIntentBase, O> {
  /// Creates a use case with an optional composed [middleware] chain.
  const UseCase({List<ZfaMiddleware<I, O>> middleware = const []})
    : _middleware = middleware;

  final List<ZfaMiddleware<I, O>> _middleware;

  /// Execute [intent] under [ctx], wrapped in the middleware chain.
  ///
  /// Returns a [Result.success] with [execute]'s output, or a
  /// [Result.failure] carrying an [AppFailure]. Cancellation and unexpected
  /// throws are funnelled onto the same [Result.failure] channel.
  Future<Result<O, AppFailure>> call(I intent, ZfaContext ctx) async {
    final pipeline = MiddlewarePipeline<I, O>();
    for (final middleware in _middleware) {
      pipeline.use(middleware);
    }

    final middlewareContext = ZfaMiddlewareContext(
      useCaseName: '$runtimeType',
      timestamp: DateTime.now(),
    );

    try {
      ctx.throwIfCancelled();
      return await pipeline.execute(
        intent,
        middlewareContext,
        (current, _) => execute(current, ctx),
      );
    } on CancellationTokenException catch (e) {
      return Result.failure(
        AppFailure.cancelled(message: e.reason ?? 'Operation was cancelled'),
      );
    } on CancelledException catch (e) {
      return Result.failure(AppFailure.cancelled(message: e.message));
    } on AppFailure catch (failure) {
      return Result.failure(failure);
    } catch (e, stackTrace) {
      return Result.failure(AppFailure.from(e, stackTrace));
    }
  }

  /// Override this to implement the use case logic.
  ///
  /// Return a [Result.success] with the output, a [Result.failure] with an
  /// expected [AppFailure], or throw — an [AppFailure] is passed through, a
  /// cancellation becomes a cancelled failure, and anything else is classified
  /// through [AppFailure.from].
  @protected
  Future<Result<O, AppFailure>> execute(I intent, ZfaContext ctx);
}
