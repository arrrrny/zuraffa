import 'package:test/test.dart';
import 'package:zuraffa/src/core/signals/signal_result.dart';
import 'package:zuraffa/src/core/context/zuraffa_context.dart';
import 'package:zuraffa/src/core/usecase_interceptor/interceptable_usecase.dart';
import 'package:zuraffa/src/core/module/interceptor.dart';

// Concrete test use case.
class _TestUseCase extends InterceptableUseCase<String, int> {
  final int Function(String) compute;

  _TestUseCase(this.compute, {super.interceptorRegistry});

  @override
  SignalResult<int> executeCall(String params, {ZuraffaContext? context}) {
    return SignalResult.success(compute(params));
  }
}

// Async concrete test use case.
class _AsyncTestUseCase extends InterceptableUseCase<String, int> {
  final Future<int> Function(String) compute;

  _AsyncTestUseCase(this.compute, {super.interceptorRegistry});

  @override
  SignalResult<int> executeCall(String params, {ZuraffaContext? context}) {
    return SignalResult.fromFuture(compute(params));
  }
}

void main() {
  group('InterceptableUseCase', () {
    test('calls executeCall when no interceptors', () {
      final uc = _TestUseCase((s) => s.length);
      final result = uc('hello');
      expect(result.isSuccess, true);
      expect(result.data, 5);
    });

    test('calls executeCall when null registry', () {
      final uc = _TestUseCase((s) => s.length, interceptorRegistry: null);
      final result = uc('hello');
      expect(result.isSuccess, true);
      expect(result.data, 5);
    });

    test('runs interceptor before executeCall', () {
      final registry = InterceptorRegistry();
      var intercepted = false;
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'log',
          handler: (req, next) {
            intercepted = true;
            return next(req);
          },
        ),
      );

      final uc = _TestUseCase((s) => s.length, interceptorRegistry: registry);
      final result = uc('hello');
      expect(intercepted, true);
      expect(result.data, 5);
    });

    test('interceptor can short-circuit', () {
      final registry = InterceptorRegistry();
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'cache',
          handler: (req, next) => SignalResult.success(-1),
        ),
      );

      final uc = _AsyncTestUseCase(
        (s) async {
          // This should never execute since the interceptor short-circuits.
          return s.length;
        },
        interceptorRegistry: registry,
      );
      final result = uc('hello');
      expect(result.data, -1);
    });

    test('multiple interceptors run in order', () {
      final registry = InterceptorRegistry();
      final order = <String>[];
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'a',
          handler: (req, next) {
            order.add('a');
            return next(req);
          },
        ),
      );
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'b',
          handler: (req, next) {
            order.add('b');
            return next(req);
          },
        ),
      );

      final uc = _TestUseCase((s) {
        order.add('uc');
        return s.length;
      }, interceptorRegistry: registry);
      uc('x');
      expect(order, ['a', 'b', 'uc']);
    });

    test('interceptor can observe without modifying', () {
      final registry = InterceptorRegistry();
      final observed = <int>[];
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'observer',
          handler: (req, next) {
            final sr = next(req);
            sr.onSuccess((v) => observed.add(v));
            return sr;
          },
        ),
      );

      final uc = _TestUseCase((s) => s.length, interceptorRegistry: registry);
      uc('hello');
      // onSuccess fires asynchronously via the signal.
      // For synchronous SignalResult.success, the listener fires
      // immediately in listen (eager delivery).
      expect(observed, [5]);
    });
  });
}
