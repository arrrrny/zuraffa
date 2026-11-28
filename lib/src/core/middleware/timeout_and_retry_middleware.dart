import 'dart:async';
import 'dart:math' as math;

import '../context/cancellation_token.dart';
import '../failure.dart';
import '../result.dart';
import 'telemetry_cost_middleware.dart' show zfaIntentReplaySafe;
import 'zfa_middleware.dart';

/// Built-in middleware that retries a failed `next` with exponential backoff
/// (ZFA-006).
///
/// A failure is retried **only** when both hold:
///
/// 1. [AppFailure.isRetryable] is `true`, **and**
/// 2. the intent is replay-safe ([ZfaIntentMetadata.replaySafe] via
///    [zfaIntentReplaySafe]) **or** the context carries an `'idempotencyKey'`
///    in [ZfaMiddlewareContext.metadata].
///
/// A `replaySafe: false` intent with no idempotency key is therefore NEVER
/// auto-retried — a non-idempotent side effect must not be replayed. The backoff
/// grows exponentially from [baseBackoff] by [multiplier] per retry, capped at
/// [maxBackoff]. When [timeout] is set, each attempt is bounded by it and a
/// timeout becomes a retryable [TimeoutFailure]. Cancellation is cooperative:
/// a [CancellationToken] carried on the context under `'cancellation'` is
/// checked before every attempt and between retries, and a cancelled scope
/// stops the loop with a [CancelledFailure].
class TimeoutAndRetryMiddleware<I, O> implements ZfaMiddleware<I, O> {
  /// Creates a retry middleware.
  ///
  /// [maxRetries] is the number of retries after the first attempt (so the
  /// total attempt count is `maxRetries + 1`). [baseBackoff] is the delay after
  /// the first failure; [multiplier] scales it per retry and [maxBackoff] caps
  /// it. [timeout] bounds each individual attempt when non-null.
  const TimeoutAndRetryMiddleware({
    this.maxRetries = 3,
    this.baseBackoff = const Duration(milliseconds: 200),
    this.multiplier = 2.0,
    this.maxBackoff = const Duration(seconds: 10),
    this.timeout,
  });

  /// Retries after the first attempt.
  final int maxRetries;

  /// The delay after the first failure.
  final Duration baseBackoff;

  /// The per-retry growth factor applied to the backoff.
  final double multiplier;

  /// The ceiling on any single backoff delay.
  final Duration maxBackoff;

  /// A per-attempt timeout, or `null` for no bound.
  final Duration? timeout;

  @override
  Future<Result<O, AppFailure>> intercept(
    I intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<I, O> next,
  ) async {
    final replaySafe = zfaIntentReplaySafe(intent as Object);
    final hasIdempotencyKey = ctx.metadata.containsKey('idempotencyKey');
    final cancellation = ctx.metadata['cancellation'];
    final token = cancellation is CancellationToken ? cancellation : null;

    var attempt = 0;
    while (true) {
      if (token?.isCancelled ?? false) {
        return Result.failure(
          AppFailure.cancelled(
            message: token?.reason ?? 'Operation was cancelled',
          ),
        );
      }
      final result = await _runAttempt(intent, ctx, next);
      if (result.isSuccess) return result;

      final failure = result.getFailureOrNull();
      final retryable = failure?.isRetryable ?? false;
      final mayReplay = replaySafe || hasIdempotencyKey;
      if (!retryable || !mayReplay || attempt >= maxRetries) {
        return result;
      }

      attempt++;
      final backoff = _backoffFor(attempt);
      if (backoff > Duration.zero) {
        await Future<void>.delayed(backoff);
      }
      // A cancellation requested during the backoff stops the loop with a
      // cancelled failure rather than replaying the intent.
      if (token?.isCancelled ?? false) {
        return Result.failure(
          AppFailure.cancelled(
            message: token?.reason ?? 'Operation was cancelled',
          ),
        );
      }
    }
  }

  Future<Result<O, AppFailure>> _runAttempt(
    I intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<I, O> next,
  ) {
    final bound = timeout;
    if (bound == null) return next(intent, ctx);
    // A timeout is modelled as a retryable timeout failure rather than an
    // escaped exception, so the same retry gate applies to it.
    return next(intent, ctx).timeout(
      bound,
      onTimeout: () => Result<O, AppFailure>.failure(
        AppFailure.timeout(
          message: 'Attempt timed out after ${bound.inMilliseconds}ms',
          isRetryable: true,
          timeout: bound,
        ),
      ),
    );
  }

  Duration _backoffFor(int retry) {
    final rawMicros =
        baseBackoff.inMicroseconds * math.pow(multiplier, retry - 1);
    final capped = rawMicros > maxBackoff.inMicroseconds
        ? maxBackoff.inMicroseconds
        : rawMicros.toInt();
    return Duration(microseconds: capped);
  }
}
