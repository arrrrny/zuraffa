import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SignalSlice', () {
    test('lazily executes use case on first access', () {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 5);
      // Accessing result triggers lazy execution.
      final result = slice.result;
      expect(result, isA<SignalResult<int>>());
      expect(slice.isLoading, true);
    });

    test('data reflects SignalResult state', () async {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 7);
      final result = await slice.result.nextValue;
      expect(result, isA<Success<int, AppFailure>>());
      expect(slice.data, 14);
      expect(slice.isSuccess, true);
    });

    test('listen only fires for this slice', () async {
      final sliceA = SignalSlice<int>(useCase: _DoubleUseCase(), params: 3);
      final sliceB = SignalSlice<int>(useCase: _DoubleUseCase(), params: 4);

      final logA = <int?>[];
      final logB = <int?>[];

      sliceA.listen((data, _) => logA.add(data));
      sliceB.listen((data, _) => logB.add(data));

      await sliceA.result.nextValue;
      await sliceB.result.nextValue;

      expect(logA.length, 2); // initial + success
      expect(logB.length, 2);
      expect(logA.last, 6);
      expect(logB.last, 8);
    });

    test('refresh re-executes use case', () async {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 2);
      await slice.result.nextValue;
      expect(slice.data, 4);

      slice.refresh(10);
      final result = await slice.result.nextValue;
      expect(result, isA<Success<int, AppFailure>>());
      expect(slice.data, 20);
    });

    test('cancelling listener after refresh stops notifications', () async {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 1);
      final values = <int?>[];
      final sub = slice.listen((data, _) => values.add(data));
      await slice.result.nextValue;
      expect(values, [null, 2]); // eager loading (null) + success (2)

      // Refresh (re-attach emits eager loading), then cancel the handle.
      slice.refresh(3);
      sub.cancel();
      await slice.result.nextValue;

      // The eager loading from re-attach is delivered, but the refreshed
      // success (6) must not reach the cancelled listener.
      expect(values, [null, 2, null]);
    });

    test('dispose releases resources', () {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 1);
      slice.dispose();
      expect(slice.isDisposed, true);
      expect(() => slice.data, throwsStateError);
    });

    test('onSuccess filters to success values', () async {
      final slice = SignalSlice<int>(useCase: _DoubleUseCase(), params: 5);
      final values = <int>[];
      slice.onSuccess(values.add);

      await slice.result.nextValue;
      expect(values, [10]);
    });
  });
}

class _DoubleUseCase extends ZuraffaUseCase<int, int> {
  @override
  SignalResult<int> call(int params, {ZuraffaContext? context}) {
    final sr = SignalResult<int>.initial(
      const LoadingResult<int, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(params * 2);
    });
    return sr;
  }
}
