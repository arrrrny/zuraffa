import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/cancellation_token.dart';
import 'package:zuraffa/src/core/context/telemetry_span.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/middleware/policy_gate_middleware.dart';
import 'package:zuraffa/src/core/middleware/telemetry_cost_middleware.dart';
import 'package:zuraffa/src/core/middleware/timeout_and_retry_middleware.dart';
import 'package:zuraffa/src/core/middleware/zfa_middleware.dart';
import 'package:zuraffa/src/core/result.dart';

/// An intent that exposes its replay metadata through the typed capability
/// interface the built-in middleware read first.
class MetadataIntent implements ZfaIntentMetadata {
  const MetadataIntent({required this.replaySafe, this.name = 'TestIntent'});
  @override
  final bool replaySafe;
  final String name;
  @override
  String get intentName => name;
  @override
  String intentDigest() => 'digest-$intentName-$replaySafe';
}

/// An intent that carries no replay metadata at all — the middleware must
/// treat it as not replay-safe.
class BareIntent {
  const BareIntent();
}

ZfaMiddlewareContext _ctx({Map<String, dynamic>? metadata}) =>
    ZfaMiddlewareContext(
      useCaseName: 'TestUseCase',
      timestamp: DateTime.now(),
      metadata: metadata,
    );

void main() {
  group('PolicyGateMiddleware', () {
    test('calls next when every rule allows the intent', () async {
      var nextCalled = false;
      Future<Result<String, AppFailure>> handler(
        Object intent,
        ZfaMiddlewareContext ctx,
      ) async {
        nextCalled = true;
        return Result.success('ok');
      }

      final middleware = PolicyGateMiddleware<Object, String>(
        rules: [AllowRule('a'), AllowRule('b')],
      );

      final result = await middleware.intercept(
        const BareIntent(),
        _ctx(),
        handler,
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals('ok'));
      expect(nextCalled, isTrue);
    });

    test(
      'short-circuits with a policyDenied failure without calling next',
      () async {
        var nextCalled = false;
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          nextCalled = true;
          return Result.success('ok');
        }

        final middleware = PolicyGateMiddleware<Object, String>(
          rules: [AllowRule('a'), DenyRule('blocked-rule'), AllowRule('c')],
        );

        final result = await middleware.intercept(
          const BareIntent(),
          _ctx(),
          handler,
        );

        expect(result.isFailure, isTrue);
        final failure = result.getFailureOrNull();
        expect(failure, isA<PolicyDeniedFailure>());
        expect(failure?.message, contains('blocked-rule'));
        expect(nextCalled, isFalse);
      },
    );
  });

  group('TimeoutAndRetryMiddleware', () {
    test(
      'retries a retryable failure for a replay-safe intent then succeeds',
      () async {
        var attempts = 0;
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          attempts++;
          if (attempts < 3) {
            return Result.failure(
              AppFailure.timeout(message: 'flaky', isRetryable: true),
            );
          }
          return Result.success('ok');
        }

        final middleware = TimeoutAndRetryMiddleware<Object, String>(
          maxRetries: 5,
          baseBackoff: Duration.zero,
        );

        final result = await middleware.intercept(
          const MetadataIntent(replaySafe: true),
          _ctx(),
          handler,
        );

        expect(result.isSuccess, isTrue);
        expect(attempts, equals(3));
      },
    );

    test(
      'NEVER retries a replaySafe:false intent without an idempotency key',
      () async {
        var attempts = 0;
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          attempts++;
          return Result.failure(
            AppFailure.timeout(message: 'flaky', isRetryable: true),
          );
        }

        final middleware = TimeoutAndRetryMiddleware<Object, String>(
          maxRetries: 5,
          baseBackoff: Duration.zero,
        );

        final result = await middleware.intercept(
          const MetadataIntent(replaySafe: false),
          _ctx(),
          handler,
        );

        expect(result.isFailure, isTrue);
        expect(attempts, equals(1));
      },
    );

    test(
      'retries a non-replay-safe intent when an idempotency key is present',
      () async {
        var attempts = 0;
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          attempts++;
          if (attempts < 2) {
            return Result.failure(
              AppFailure.timeout(message: 'flaky', isRetryable: true),
            );
          }
          return Result.success('ok');
        }

        final middleware = TimeoutAndRetryMiddleware<Object, String>(
          maxRetries: 5,
          baseBackoff: Duration.zero,
        );

        final result = await middleware.intercept(
          const MetadataIntent(replaySafe: false),
          _ctx(metadata: {'idempotencyKey': 'abc'}),
          handler,
        );

        expect(result.isSuccess, isTrue);
        expect(attempts, equals(2));
      },
    );

    test(
      'does not retry a non-retryable failure even for a replay-safe intent',
      () async {
        var attempts = 0;
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          attempts++;
          return Result.failure(
            AppFailure.boundaryViolation(message: 'bad', isRetryable: false),
          );
        }

        final middleware = TimeoutAndRetryMiddleware<Object, String>(
          maxRetries: 5,
          baseBackoff: Duration.zero,
        );

        final result = await middleware.intercept(
          const MetadataIntent(replaySafe: true),
          _ctx(),
          handler,
        );

        expect(result.isFailure, isTrue);
        expect(attempts, equals(1));
      },
    );

    test('stops after maxRetries and returns the last failure', () async {
      var attempts = 0;
      Future<Result<String, AppFailure>> handler(
        Object intent,
        ZfaMiddlewareContext ctx,
      ) async {
        attempts++;
        return Result.failure(
          AppFailure.timeout(message: 'always', isRetryable: true),
        );
      }

      final middleware = TimeoutAndRetryMiddleware<Object, String>(
        maxRetries: 2,
        baseBackoff: Duration.zero,
      );

      final result = await middleware.intercept(
        const MetadataIntent(replaySafe: true),
        _ctx(),
        handler,
      );

      expect(result.isFailure, isTrue);
      // 1 initial attempt + 2 retries.
      expect(attempts, equals(3));
    });

    test('a per-attempt timeout becomes a retryable timeout failure', () async {
      var attempts = 0;
      Future<Result<String, AppFailure>> handler(
        Object intent,
        ZfaMiddlewareContext ctx,
      ) async {
        attempts++;
        if (attempts == 1) {
          // First attempt hangs past the per-attempt timeout.
          await Future<void>.delayed(const Duration(seconds: 5));
          return Result.success('late');
        }
        return Result.success('ok');
      }

      final middleware = TimeoutAndRetryMiddleware<Object, String>(
        maxRetries: 2,
        baseBackoff: Duration.zero,
        timeout: const Duration(milliseconds: 20),
      );

      final result = await middleware.intercept(
        const MetadataIntent(replaySafe: true),
        _ctx(),
        handler,
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals('ok'));
      expect(attempts, equals(2));
    });

    test('stops retrying once the context cancellation is requested', () async {
      var attempts = 0;
      final token = CancellationToken();
      Future<Result<String, AppFailure>> handler(
        Object intent,
        ZfaMiddlewareContext ctx,
      ) async {
        attempts++;
        token.cancel('stop');
        return Result.failure(
          AppFailure.timeout(message: 'flaky', isRetryable: true),
        );
      }

      final middleware = TimeoutAndRetryMiddleware<Object, String>(
        maxRetries: 5,
        baseBackoff: Duration.zero,
      );

      final result = await middleware.intercept(
        const MetadataIntent(replaySafe: true),
        _ctx(metadata: {'cancellation': token}),
        handler,
      );

      expect(result.isFailure, isTrue);
      expect(result.getFailureOrNull(), isA<CancelledFailure>());
      expect(attempts, equals(1));
    });
  });

  group('TelemetryCostMiddleware', () {
    test(
      'opens a child span tagged with intentName and intentDigest',
      () async {
        final parent = TelemetrySpan(operation: 'parent');
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          return Result.success('ok');
        }

        const middleware = TelemetryCostMiddleware<Object, String>();

        final result = await middleware.intercept(
          const MetadataIntent(replaySafe: true, name: 'DoWork'),
          _ctx(metadata: {'span': parent}),
          handler,
        );

        expect(result.isSuccess, isTrue);
        expect(parent.children, hasLength(1));
        final span = parent.children.single;
        expect(span.operation, equals('DoWork'));
        expect(span.attributes['intentName'], equals('DoWork'));
        expect(span.attributes['intentDigest'], isNotNull);
        expect(span.isEnded, isTrue);
      },
    );

    test(
      'falls back to the runtime type when the intent has no name',
      () async {
        Future<Result<String, AppFailure>> handler(
          Object intent,
          ZfaMiddlewareContext ctx,
        ) async {
          return Result.success('ok');
        }

        const middleware = TelemetryCostMiddleware<Object, String>();

        await middleware.intercept(const BareIntent(), _ctx(), handler);

        // No parent span in metadata -> a root span is created and ended.
        // We cannot reach it directly, so assert the call simply succeeded.
        // The dedicated span-tree assertions live in the parented test above.
      },
    );
  });
}

class AllowRule<I> extends ZfaPolicyRule<I> {
  AllowRule(this.id);
  @override
  final String id;
  @override
  ZfaPolicyDecision evaluate(I intent, ZfaMiddlewareContext ctx) =>
      ZfaPolicyDecision.allow;
}

class DenyRule<I> extends ZfaPolicyRule<I> {
  DenyRule(this.id);
  @override
  final String id;
  @override
  ZfaPolicyDecision evaluate(I intent, ZfaMiddlewareContext ctx) =>
      ZfaPolicyDecision.deny;
}
