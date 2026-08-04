import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/interceptor.dart';
import 'package:zuraffa/src/core/signals/signal_result.dart';

void main() {
  group('InterceptorRegistry', () {
    late InterceptorRegistry registry;

    setUp(() {
      registry = InterceptorRegistry();
    });

    test('isEmpty is true when no interceptors registered', () {
      expect(registry.isEmpty, true);
    });

    test('entriesFor returns empty list when none registered', () {
      final entries = registry.entriesFor<String, int>();
      expect(entries, isEmpty);
    });

    test('register adds entry for the correct type', () {
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'a',
          handler: (req, next) => next(req),
        ),
      );
      expect(registry.isEmpty, false);

      final entries = registry.entriesFor<String, int>();
      expect(entries.length, 1);
      expect(entries.first.name, 'a');
    });

    test('entriesFor returns empty for wrong type', () {
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'a',
          handler: (req, next) => next(req),
        ),
      );
      expect(registry.entriesFor<int, String>(), isEmpty);
    });

    test('chain returns tail when no interceptors', () {
      SignalResult<int> tail(String req) => SignalResult.success(42);
      final chained = registry.chain<String, int>(tail);
      expect(identical(chained, tail), true);
    });

    test('chain runs single interceptor before tail', () {
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

      SignalResult<int> tail(String req) => SignalResult.success(req.length);
      final chained = registry.chain<String, int>(tail);
      final result = chained('hello');
      expect(intercepted, true);
      expect(result.data, 5);
    });

    test('chain runs interceptors in registration order', () {
      final order = <String>[];
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'first',
          handler: (req, next) {
            order.add('first');
            return next(req);
          },
        ),
      );
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'second',
          handler: (req, next) {
            order.add('second');
            return next(req);
          },
        ),
      );

      SignalResult<int> tail(String req) {
        order.add('tail');
        return SignalResult.success(99);
      }
      final chained = registry.chain<String, int>(tail);
      chained('x');
      expect(order, ['first', 'second', 'tail']);
    });

    test('chain allows interceptor to short-circuit', () {
      var tailCalled = false;
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'cache',
          handler: (req, next) {
            // Short-circuit: return cached value without calling next.
            return SignalResult.success(-1);
          },
        ),
      );

      SignalResult<int> tail(String req) {
        tailCalled = true;
        return SignalResult.success(42);
      }
      final chained = registry.chain<String, int>(tail);
      final result = chained('x');
      expect(tailCalled, false);
      expect(result.data, -1);
    });

    test('chain allows interceptor to transform result', () {
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'doubler',
          handler: (req, next) {
            final sr = next(req);
            return sr.map((v) => v * 2);
          },
        ),
      );

      SignalResult<int> tail(String req) => SignalResult.success(10);
      final chained = registry.chain<String, int>(tail);
      final result = chained('x');
      expect(result.isSuccess, true);
      expect(result.data, 20);
    });

    test('clear removes all interceptors', () {
      registry.register<String, int>(
        InterceptorEntry<String, int>(
          name: 'a',
          handler: (req, next) => next(req),
        ),
      );
      registry.clear();
      expect(registry.isEmpty, true);
    });
  });
}
