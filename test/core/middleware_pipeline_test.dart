import 'dart:async';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/result.dart';
import 'package:zuraffa/src/core/middleware/zfa_middleware.dart';
import 'package:zuraffa/src/core/middleware/middleware_pipeline.dart';

class TestIntent {
  final String value;
  TestIntent(this.value);
}

class TestMiddleware implements ZfaMiddleware<TestIntent, String> {
  final String prefix;
  TestMiddleware(this.prefix);

  @override
  Future<Result<String, AppFailure>> intercept(
    TestIntent intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<TestIntent, String> next,
  ) async {
    ctx.metadata['log'] = (ctx.metadata['log'] as List<String>? ?? [])
      ..add('$prefix-pre');
    final res = await next(intent, ctx);
    return res.map((s) => '$prefix-$s');
  }
}

/// Returns without invoking [next] — models a policy gate that short-circuits.
class ShortCircuitMiddleware implements ZfaMiddleware<TestIntent, String> {
  @override
  Future<Result<String, AppFailure>> intercept(
    TestIntent intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<TestIntent, String> next,
  ) async {
    ctx.metadata['log'] = (ctx.metadata['log'] as List<String>? ?? [])
      ..add('short-circuit');
    return Result.success('short-circuited');
  }
}

/// Returns a failure without invoking [next] — models a failing inner layer.
class FailingMiddleware implements ZfaMiddleware<TestIntent, String> {
  @override
  Future<Result<String, AppFailure>> intercept(
    TestIntent intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<TestIntent, String> next,
  ) async {
    ctx.metadata['log'] = (ctx.metadata['log'] as List<String>? ?? [])
      ..add('fail-pre');
    return Result.failure(AppFailure.boundaryViolation(message: 'blocked'));
  }
}

void main() {
  group('MiddlewarePipeline', () {
    test('composes deterministically and propagates context', () async {
      final m1 = TestMiddleware('m1');
      final m2 = TestMiddleware('m2');

      Future<Result<String, AppFailure>> handler(
        TestIntent intent,
        ZfaMiddlewareContext ctx,
      ) async {
        (ctx.metadata['log'] as List<String>).add('handler');
        return Result.success('ok-${intent.value}');
      }

      final pipeline = MiddlewarePipeline<TestIntent, String>()
        ..use(m1)
        ..use(m2);

      final ctx = ZfaMiddlewareContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );
      final result = await pipeline.execute(TestIntent('test'), ctx, handler);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals('m1-m2-ok-test'));
      expect(ctx.metadata['log'], equals(['m1-pre', 'm2-pre', 'handler']));
    });

    test(
      'short-circuits without calling next, skipping handler and inner middleware',
      () async {
        final inner = TestMiddleware('inner');

        Future<Result<String, AppFailure>> handler(
          TestIntent intent,
          ZfaMiddlewareContext ctx,
        ) async {
          (ctx.metadata['log'] as List<String>).add('handler');
          return Result.success('ok-${intent.value}');
        }

        final pipeline = MiddlewarePipeline<TestIntent, String>()
          ..use(ShortCircuitMiddleware())
          ..use(inner);

        final ctx = ZfaMiddlewareContext(
          useCaseName: 'ShortCircuitUseCase',
          timestamp: DateTime.now(),
        );
        final result = await pipeline.execute(TestIntent('test'), ctx, handler);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), equals('short-circuited'));
        // Neither the inner middleware nor the handler ran, so no outer `map`
        // wrapped the short-circuit value.
        expect(ctx.metadata['log'], equals(['short-circuit']));
      },
    );

    test('propagates a failure and bypasses outer middleware map', () async {
      final outer = TestMiddleware('outer');

      Future<Result<String, AppFailure>> handler(
        TestIntent intent,
        ZfaMiddlewareContext ctx,
      ) async {
        (ctx.metadata['log'] as List<String>).add('handler');
        return Result.success('ok-${intent.value}');
      }

      final pipeline = MiddlewarePipeline<TestIntent, String>()
        ..use(outer)
        ..use(FailingMiddleware());

      final ctx = ZfaMiddlewareContext(
        useCaseName: 'FailureUseCase',
        timestamp: DateTime.now(),
      );
      final result = await pipeline.execute(TestIntent('test'), ctx, handler);

      expect(result.isFailure, isTrue);
      expect(result.getFailureOrNull(), isA<BoundaryViolationFailure>());
      expect(result.getFailureOrNull()?.message, equals('blocked'));
      // Handler never ran; outer `map` was bypassed so no 'outer-' prefix was
      // applied to the failure.
      expect(ctx.metadata['log'], equals(['outer-pre', 'fail-pre']));
    });
  });
}
