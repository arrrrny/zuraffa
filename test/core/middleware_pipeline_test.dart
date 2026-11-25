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
    ZfaContext ctx,
    NextUseCase<TestIntent, String> next,
  ) async {
    ctx.metadata['log'] = (ctx.metadata['log'] as List<String>? ?? [])
      ..add('$prefix-pre');
    final res = await next(intent, ctx);
    return res.map((s) => '$prefix-$s');
  }
}

void main() {
  group('MiddlewarePipeline', () {
    test('composes deterministically and propagates context', () async {
      final m1 = TestMiddleware('m1');
      final m2 = TestMiddleware('m2');

      Future<Result<String, AppFailure>> handler(
        TestIntent intent,
        ZfaContext ctx,
      ) async {
        (ctx.metadata['log'] as List<String>).add('handler');
        return Result.success('ok-${intent.value}');
      }

      final pipeline = MiddlewarePipeline<TestIntent, String>()
        ..use(m1)
        ..use(m2);

      final ctx = ZfaContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );
      final result = await pipeline.execute(TestIntent('test'), ctx, handler);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals('m1-m2-ok-test'));
      expect(ctx.metadata['log'], equals(['m1-pre', 'm2-pre', 'handler']));
    });
  });
}
