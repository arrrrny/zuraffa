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
import '../signals/zfa_signal.dart';

/// The v8 watch use case archetype.
///
/// A [WatchUseCase] exposes a single business operation as a reactive
/// [ZfaSignal] of [Result] values. [watch] returns a signal synchronously,
/// seeded with the current value from [read] (the same value a synchronous
/// caller would observe "now"), and then schedules [execute] to refresh the
/// signal once the asynchronous work completes. Each refresh runs through the
/// optional composed [ZfaMiddleware] chain.
///
/// The returned signal is bound to [watch]'s `owner`: disposing the owner (via
/// [ZfaSignal.disposeOwner]) disposes the signal, so a screen that goes away
/// leaves no live subscription behind.
///
/// ## Example
///
/// ```dart
/// class WatchCountUseCase extends WatchUseCase<CountIntent, int> {
///   @override
///   Result<int, AppFailure> read(CountIntent intent, ZfaContext ctx) =>
///       Result.success(intent.current);
///
///   @override
///   Future<Result<int, AppFailure>> execute(CountIntent intent, ZfaContext ctx) async {
///     ctx.throwIfCancelled();
///     return Result.success(await _loadCount());
///   }
/// }
///
/// final signal = WatchCountUseCase().watch(intent, ctx, owner: this);
/// ```
abstract class WatchUseCase<I extends ZorphyIntentBase, O> {
  /// Creates a watch use case with an optional composed [middleware] chain.
  WatchUseCase({List<ZfaMiddleware<I, O>> middleware = const []})
    : _pipeline = _composePipeline(middleware);

  /// The composed middleware pipeline, built once at construction.
  ///
  /// The middleware set is fixed per instance, so the pipeline is composed a
  /// single time here and reused across every refresh instead of being rebuilt
  /// on each one.
  final MiddlewarePipeline<I, O> _pipeline;

  static MiddlewarePipeline<I, O> _composePipeline<
    I extends ZorphyIntentBase,
    O
  >(List<ZfaMiddleware<I, O>> middleware) {
    final pipeline = MiddlewarePipeline<I, O>();
    for (final m in middleware) {
      pipeline.use(m);
    }
    return pipeline;
  }

  /// Return an owner-bound signal for [intent] under [ctx].
  ///
  /// The signal is seeded synchronously with [read] and refreshed once
  /// [execute] completes. The signal is bound to [owner] so that
  /// [ZfaSignal.disposeOwner] disposes it together with its owner.
  ZfaSignal<Result<O, AppFailure>> watch(
    I intent,
    ZfaContext ctx, {
    required Object owner,
  }) {
    final seed = _readSafely(intent, ctx);
    final signal = ZfaSignal<Result<O, AppFailure>>(seed, owner: owner);
    scheduleMicrotask(() async {
      // Skip the async execute work entirely if the owner was disposed between
      // watch() returning and this microtask firing — the result would only be
      // discarded.
      if (signal.isDisposed) return;
      final refreshed = await _executeThroughPipeline(intent, ctx);
      if (signal.isDisposed) return;
      signal.value = refreshed;
    });
    return signal;
  }

  /// The current value of the operation, observed synchronously.
  ///
  /// This is the signal's seed — what a synchronous caller sees before the
  /// first asynchronous [execute] refresh lands. Throw an [AppFailure] (or any
  /// error) to seed a failure; it is funnelled onto the same channel.
  @protected
  Result<O, AppFailure> read(I intent, ZfaContext ctx);

  /// Refresh the operation asynchronously.
  ///
  /// The returned result replaces the signal's value when it completes. Throw
  /// an [AppFailure] (or any error) to publish a failure; cancellation becomes
  /// a cancelled failure.
  @protected
  Future<Result<O, AppFailure>> execute(I intent, ZfaContext ctx);

  Result<O, AppFailure> _readSafely(I intent, ZfaContext ctx) {
    try {
      return read(intent, ctx);
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

  Future<Result<O, AppFailure>> _executeThroughPipeline(
    I intent,
    ZfaContext ctx,
  ) async {
    final middlewareContext = ZfaMiddlewareContext(
      useCaseName: '$runtimeType',
      timestamp: DateTime.now(),
    );

    try {
      ctx.throwIfCancelled();
      return await _pipeline.execute(
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
}
