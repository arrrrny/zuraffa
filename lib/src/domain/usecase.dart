import 'dart:async';

import 'package:meta/meta.dart';

import '../core/cancel_token.dart';
import '../core/failure.dart';
import '../core/failure_reporter_registry.dart';
import '../core/hook.dart';
import '../core/hook_registry.dart';
import '../core/loggable.dart';
import '../core/trace_observer.dart';
import '../core/result.dart';

/// Base UseCase class for Clean Architecture.
///
/// A UseCase represents a single business operation. It encapsulates
/// the application's business logic and returns a [Result] indicating
/// success or failure.
///
/// This is the **default** UseCase type for single-shot operations.
/// For streaming/reactive operations, use [StreamUseCase].
/// For operations that don't return a value, use [CompletableUseCase].
///
/// ## Key Features
/// - Returns [Result<Type, AppFailure>] for type-safe error handling
/// - Built-in cancellation support via [CancelToken]
/// - Automatic error wrapping and logging
/// - Callable syntax for clean API
/// - Blocking (awaited) pre hooks via [Hook.blocking] — ordering-critical
///   side effects complete before [execute] begins (issue #2032)
///
/// ## Example
/// ```dart
/// class GetUserUseCase extends UseCase<User, String> {
///   final UserRepository _repository;
///
///   GetUserUseCase(this._repository);
///
///   @override
///   Future<User> execute(String userId, CancelToken? cancelToken) async {
///     return _repository.getUser(userId);
///   }
/// }
///
/// // Usage
/// final result = await getUserUseCase('user-123');
/// result.fold(
///   (user) => print('Got user: ${user.name}'),
///   (failure) => print('Error: ${failure.message}'),
/// );
/// ```
///
/// ## Error Handling
/// - Throw [AppFailure] subclasses for expected errors
/// - Any other exception is automatically wrapped in [UnknownFailure]
/// - [CancelledException] is converted to [CancellationFailure]
abstract class UseCase<T, Params> with Loggable {
  /// Execute the use case with the given [params].
  ///
  /// Prefer using the call syntax: `await useCase(params)`
  /// instead of: `await useCase.call(params)`
  ///
  /// Returns a [Result] that is either:
  /// - [Success] containing the result value
  /// - [Failure] containing an [AppFailure]
  Future<Result<T, AppFailure>> call(
    Params params, {
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    final traceCtx = (
      traceId: TraceObserver.instance.currentTraceId,
      spanId: TraceObserver.instance.currentSpanId,
    );

    // Shared metadata bag — hooks can write in pre, read in success/failure
    final hookMetadata = <String, dynamic>{};

    // Pre phase — blocking hooks (Hook.blocking) are awaited to completion
    // BEFORE execute begins (issue #2032); non-blocking hooks keep the
    // fire-and-forget contract above. A vetoing hook fails the call here:
    // Failure(hookFailure) without running execute, without later phases
    // (not reported to FailureReporterRegistry — the UseCase never ran).
    // No success/failure dispatch on veto also means a hook that acquires
    // a resource in pre (a telemetry span) never reaches its release phase
    // — such hooks must self-release; see HookVetoException.
    try {
      await HookRegistry.instance.dispatchAwaited(
        HookContext(
          useCaseName: '$runtimeType',
          params: params,
          timestamp: startTime,
          traceId: traceCtx.traceId,
          spanId: traceCtx.spanId,
          metadata: hookMetadata,
        ),
        HookPhase.pre,
      );
    } on HookVetoException catch (e) {
      logger.warning(
        '$runtimeType vetoed by blocking pre hook "${e.hookId}": '
        '${e.failure}',
      );
      return Result.failure(e.failure);
    } catch (e, stackTrace) {
      // The pre dispatch must never take the UseCase down (the dispatch
      // contract is never-throw); a synchronous shouldTrigger crash would
      // have escaped call() entirely before dispatchAwaited existed.
      logger.warning(
        '$runtimeType pre hook dispatch failed unexpectedly: $e',
        e,
        stackTrace,
      );
    }

    try {
      // Check for cancellation before starting
      cancelToken?.throwIfCancelled();

      final value = await execute(params, cancelToken);

      logger.fine('$runtimeType completed successfully');

      HookRegistry.instance.dispatch(
        HookContext(
          useCaseName: '$runtimeType',
          params: params,
          result: value,
          duration: DateTime.now().difference(startTime),
          timestamp: startTime,
          traceId: traceCtx.traceId,
          spanId: traceCtx.spanId,
          metadata: hookMetadata,
        ),
        HookPhase.success,
      );

      return Result.success(value);
    } on CancelledException catch (e) {
      logger.info('$runtimeType was cancelled: ${e.message}');
      return Result.failure(CancellationFailure(e.message));
    } on AppFailure catch (e) {
      logger.warning('$runtimeType failed with AppFailure: $e');
      FailureReporterRegistry.instance.reportFailure(
        e,
        stackTrace: e.stackTrace,
        attributes: {'usecase': '$runtimeType'},
      );

      HookRegistry.instance.dispatch(
        HookContext(
          useCaseName: '$runtimeType',
          params: params,
          failure: e,
          duration: DateTime.now().difference(startTime),
          timestamp: startTime,
          traceId: traceCtx.traceId,
          spanId: traceCtx.spanId,
          metadata: hookMetadata,
        ),
        HookPhase.failure,
      );

      return Result.failure(e);
    } catch (e, stackTrace) {
      logger.severe('$runtimeType failed unexpectedly', e, stackTrace);
      final failure = AppFailure.from(e, stackTrace);
      FailureReporterRegistry.instance.reportFailure(
        failure,
        stackTrace: stackTrace,
        attributes: {'usecase': '$runtimeType'},
      );

      HookRegistry.instance.dispatch(
        HookContext(
          useCaseName: '$runtimeType',
          params: params,
          failure: failure,
          duration: DateTime.now().difference(startTime),
          timestamp: startTime,
          traceId: traceCtx.traceId,
          spanId: traceCtx.spanId,
          metadata: hookMetadata,
        ),
        HookPhase.failure,
      );

      return Result.failure(failure);
    }
  }

  /// Override this method to implement the use case logic.
  ///
  /// - Throw [AppFailure] subclasses for expected/recoverable errors
  /// - Any other exception will be wrapped in [UnknownFailure]
  /// - Periodically check `cancelToken?.throwIfCancelled()` for long operations
  ///
  /// The returned value will be wrapped in [Success].
  @protected
  Future<T> execute(Params params, CancelToken? cancelToken);
}

/// A UseCase that doesn't return a value.
///
/// Use this for operations like delete, logout, or fire-and-forget actions.
///
/// ## Example
/// ```dart
/// class LogoutUseCase extends CompletableUseCase<NoParams> {
///   final AuthRepository _repository;
///
///   LogoutUseCase(this._repository);
///
///   @override
///   Future<void> execute(NoParams params, CancelToken? cancelToken) async {
///     await _repository.logout();
///   }
/// }
///
/// // Usage
/// final result = await logoutUseCase(const NoParams());
/// result.fold(
///   (_) => print('Logged out successfully'),
///   (failure) => print('Logout failed: ${failure.message}'),
/// );
/// ```
abstract class CompletableUseCase<Params> extends UseCase<void, Params> {
  @override
  @protected
  Future<void> execute(Params params, CancelToken? cancelToken);
}
