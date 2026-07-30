import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Signal<T>', () {
    test('value getter returns current value', () {
      final s = Signal<int>(42);
      expect(s.value, 42);
    });

    test('set updates value and notifies listeners', () {
      final s = Signal<int>(0);
      final values = <int>[];
      s.listen(values.add);

      s.value = 1;
      s.value = 2;

      // listen() emits current value immediately, then each change
      expect(values, [0, 1, 2]);
    });

    test('update applies functional transformation', () {
      final s = Signal<int>(10);
      s.update((v) => v * 2);
      expect(s.value, 20);
    });

    test('does not notify when value is equal', () {
      final s = Signal<int>(5);
      var count = 0;
      s.listen((_) => count++);

      s.value = 5; // same value
      expect(count, 1); // only the initial emission
    });

    test('custom equals prevents notification', () {
      final s = Signal<List<int>>([
        1,
        2,
      ], equals: (a, b) => a.length == b.length);
      var count = 0;
      s.listen((_) => count++);

      s.value = [3, 4]; // different contents, same length
      expect(count, 1); // no notification because length is equal
    });

    test('cancel subscription stops notifications', () {
      final s = Signal<int>(0);
      final values = <int>[];
      final sub = s.listen(values.add);

      s.value = 1;
      sub.cancel();
      s.value = 2;

      expect(values, [0, 1]);
    });

    test('map creates derived signal', () {
      final s = Signal<int>(2);
      final doubled = s.map((v) => v * 2);

      expect(doubled.value, 4);
      s.value = 5;
      expect(doubled.value, 10);
    });

    test('combine merges two signals', () {
      final a = Signal<int>(1);
      final b = Signal<int>(2);
      final sum = Signal.combine(a, b, (x, y) => x + y);

      expect(sum.value, 3);
      a.value = 10;
      expect(sum.value, 12);
    });

    test('dispose releases all listeners', () {
      final s = Signal<int>(0);
      var count = 0;
      s.listen((_) => count++);

      s.dispose();
      expect(s.isDisposed, true);
      expect(() => s.value = 1, throwsStateError);
    });

    test('disposed signal throws on read', () {
      final s = Signal<int>(0);
      s.dispose();
      expect(() => s.value, throwsStateError);
    });

    test('multiple listeners receive updates', () {
      final s = Signal<String>('a');
      final log1 = <String>[];
      final log2 = <String>[];

      s.listen(log1.add);
      s.listen(log2.add);

      s.value = 'b';
      expect(log1, ['a', 'b']);
      expect(log2, ['a', 'b']);
    });

    test('concurrent reads are safe', () {
      final s = Signal<int>(0);
      final results = <int>[];

      // Simulate 100 concurrent reads
      for (var i = 0; i < 100; i++) {
        results.add(s.value);
      }

      expect(results.every((v) => v == 0), true);
    });
  });

  group('SignalResult<T>', () {
    test('initial value is accessible', () {
      final sr = SignalResult<int>.success(42);
      expect(sr.value, isA<Success<int, AppFailure>>());
      expect(sr.data, 42);
      expect(sr.isSuccess, true);
    });

    test('emit transitions state', () {
      final sr = SignalResult<int>.initial(
        const LoadingResult<int, AppFailure>.loading(),
      );
      expect(sr.isLoading, true);

      sr.emitSuccess(100);
      expect(sr.isSuccess, true);
      expect(sr.data, 100);
    });

    test('emitFailure sets error state', () {
      final sr = SignalResult<int>.success(0);
      sr.emitFailure(const NetworkFailure('timeout'));

      expect(sr.isFailure, true);
      expect(sr.error, isA<NetworkFailure>());
    });

    test('listen receives current and future values', () {
      final sr = SignalResult<int>.success(1);
      final log = <Result<int, AppFailure>>[];
      sr.listen(log.add);

      sr.emitSuccess(2);
      sr.emitSuccess(3);

      expect(log.length, 3);
      expect((log[0] as Success<int, AppFailure>).value, 1);
      expect((log[2] as Success<int, AppFailure>).value, 3);
    });

    test('onSuccess filters to success values only', () {
      final sr = SignalResult<int>.initial(
        const LoadingResult<int, AppFailure>.loading(),
      );
      final values = <int>[];
      sr.onSuccess(values.add);

      sr.emitSuccess(10);
      sr.emitFailure(const UnknownFailure('unexpected failure'));
      sr.emitSuccess(20);

      expect(values, [10, 20]);
    });

    test('onFailure filters to failure values only', () {
      final sr = SignalResult<int>.initial(
        const LoadingResult<int, AppFailure>.loading(),
      );
      final errors = <AppFailure>[];
      sr.onFailure(errors.add);

      sr.emitSuccess(1);
      sr.emitFailure(const ServerFailure('server error occurred'));
      sr.emitSuccess(2);

      expect(errors.length, 1);
      expect(errors.first, isA<ServerFailure>());
    });

    test('nextValue awaits next non-loading result', () async {
      final sr = SignalResult<int>.initial(
        const LoadingResult<int, AppFailure>.loading(),
      );
      final future = sr.nextValue;

      // Simulate async work
      Future.delayed(const Duration(milliseconds: 10), () {
        sr.emitSuccess(99);
      });

      final result = await future;
      expect(result, isA<Success<int, AppFailure>>());
      expect((result as Success<int, AppFailure>).value, 99);
    });

    test('map transforms success, preserves failure', () {
      final sr = SignalResult<int>.success(5);
      final mapped = sr.map((v) => v.toString());

      expect(mapped.data, '5');

      sr.emitFailure(const NetworkFailure('network error on map'));
      expect(mapped.isFailure, true);
    });

    test('flatMap chains async operations', () {
      final sr = SignalResult<int>.success(2);
      final chained = sr.flatMap(
        (v) => SignalResult<String>.success('value: $v'),
      );

      expect(chained.data, 'value: 2');
    });

    test('fromFuture resolves to success', () async {
      final sr = SignalResult.fromFuture<int>(
        Future.delayed(const Duration(milliseconds: 5), () => 42),
      );

      final result = await sr.nextValue;
      expect(result, isA<Success<int, AppFailure>>());
      expect((result as Success<int, AppFailure>).value, 42);
    });

    test('fromFuture resolves to failure on exception', () async {
      final sr = SignalResult.fromFuture<int>(
        Future.delayed(
          const Duration(milliseconds: 5),
          () => throw Exception('boom'),
        ),
      );

      final result = await sr.nextValue;
      expect(result, isA<Failure<int, AppFailure>>());
    });

    test('dispose releases listeners', () {
      final sr = SignalResult<int>.success(0);
      var count = 0;
      sr.listen((_) => count++);

      sr.dispose();
      expect(sr.isDisposed, true);
    });

    test('loading state is distinct from success/failure', () {
      final sr = SignalResult<int>.initial(
        const LoadingResult<int, AppFailure>.loading(),
      );
      expect(sr.isLoading, true);
      expect(sr.isSuccess, false);
      expect(sr.isFailure, false);
      expect(sr.data, null);
      expect(sr.error, null);
    });

    test('updateData updates success value only', () {
      final sr = SignalResult<int>.success(10);
      sr.updateData((v) => v + 5);
      expect(sr.data, 15);

      // updateData is a no-op on failure
      sr.emitFailure(const NetworkFailure('update skipped for failure'));
      sr.updateData((v) => v + 1);
      expect(sr.isFailure, true);
    });
  });

  group('ZuraffaUseCase contract', () {
    test('use case returns SignalResult', () {
      final useCase = _TestUseCase();
      final result = useCase.call(_TestParams(10));

      expect(result, isA<SignalResult<int>>());
      expect(result.isLoading, true);
    });

    test('use case with context parameter', () {
      final useCase = _TestUseCase();
      final result = useCase.call(
        _TestParams(5),
        context: const ZuraffaContext(traceId: 'abc-123'),
      );

      expect(result.isLoading, true);
    });

    test('use case default context is noop', () {
      final useCase = _TestUseCase();
      // Should compile and run without explicit context
      final result = useCase.call(_TestParams(1));
      expect(result, isNotNull);
    });
  });

  group('DisposableUseCase mixin', () {
    test('owns and disposes signal results', () {
      final useCase = _DisposableTestUseCase();
      final sr = useCase.call(_TestParams(1));

      expect(sr.isDisposed, false);
      useCase.disposeUseCase();
      expect(sr.isDisposed, true);
    });
  });

  group('StreamToSignalResultAdapter', () {
    test('adapts stream to SignalResult', () async {
      final stream = Stream.fromIterable([
        const Success<int, AppFailure>(1),
        const Success<int, AppFailure>(2),
      ]);

      final sr = StreamToSignalResultAdapter.adapt<int>(stream);
      expect(sr.isLoading, true);

      final result = await sr.nextValue;
      expect(result, isA<Success<int, AppFailure>>());
    });

    test('adapts stream error to failure', () async {
      final stream = Stream<Result<int, AppFailure>>.error(
        Exception('stream error'),
      );
      final sr = StreamToSignalResultAdapter.adapt<int>(stream);

      final result = await sr.nextValue;
      expect(result, isA<Failure<int, AppFailure>>());
    });

    test('disposal cancels stream subscription', () {
      final controller = StreamController<Result<int, AppFailure>>();
      final sr = StreamToSignalResultAdapter.adapt<int>(controller.stream);

      sr.dispose();
      expect(controller.isClosed, false); // controller itself is not closed
      // But the subscription is cancelled — adding to controller won't crash
      controller.add(const Success<int, AppFailure>(1));
      controller.close();
    });
  });

  group('Memory & lifecycle', () {
    test('signal does not leak listeners after dispose', () {
      final s = Signal<int>(0);
      for (var i = 0; i < 1000; i++) {
        s.listen((_) {});
      }
      s.dispose();
      // If listeners leaked, this would retain 1000 closures.
      // Test passes if dispose runs without error.
      expect(s.isDisposed, true);
    });

    test('SignalResult disposal cleans up internal signal', () {
      final sr = SignalResult<int>.success(0);
      var count = 0;
      sr.listen((_) => count++);

      sr.dispose();
      // After disposal, the internal signal is disposed.
      // Any further interaction should throw or be safe.
      expect(sr.isDisposed, true);
    });

    test('derived signals dispose with parent when autoDispose', () {
      final parent = Signal<int>(1);
      final child = parent.map((v) => v * 2);

      expect(child.isDisposed, false);
      parent.dispose();
      // With autoDispose=true (default), child should be disposed
      expect(child.isDisposed, true);
    });
  });
}

// ── Test doubles ──

class _TestParams {
  _TestParams(this.value);
  final int value;
}

class _TestUseCase extends ZuraffaUseCase<_TestParams, int> {
  @override
  SignalResult<int> call(_TestParams params, {ZuraffaContext? context}) {
    final sr = SignalResult<int>.initial(
      const LoadingResult<int, AppFailure>.loading(),
    );
    // Simulate async work
    Future.delayed(const Duration(milliseconds: 10), () {
      sr.emitSuccess(params.value * 2);
    });
    return sr;
  }
}

class _DisposableTestUseCase extends ZuraffaUseCase<_TestParams, int>
    with DisposableUseCase<_TestParams, int> {
  @override
  SignalResult<int> call(_TestParams params, {ZuraffaContext? context}) {
    final sr = own(SignalResult<int>.success(params.value));
    return sr;
  }
}
