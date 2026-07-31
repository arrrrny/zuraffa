import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SignalBuilder', () {
    test('rebuilds when signal changes', () {
      final signal = Signal<int>(0);
      var buildCount = 0;
      var lastValue = -1;

      // Simulate widget lifecycle
      final subscription = signal.listen((value) {
        buildCount++;
        lastValue = value;
      });

      signal.value = 1;
      signal.value = 2;

      expect(buildCount, 3); // initial + 2 changes
      expect(lastValue, 2);

      subscription.cancel();
    });

    test('cancels subscription on dispose', () {
      final signal = Signal<String>('a');
      final sub = signal.listen((_) {});
      sub.cancel();

      var count = 0;
      signal.listen((_) => count++);

      signal.value = 'b';
      // Eager initial delivery + one change = 2 for the new listener.
      expect(count, 2);
    });
  });

  group('FragmentBuilder states', () {
    test('shows loading when data is null and loading', () async {
      final slice = SignalSlice<int>(useCase: _SlowUseCase(), params: 42);

      expect(slice.isLoading, true);
      expect(slice.data, null);

      await slice.result.nextValue;
      expect(slice.isSuccess, true);
      expect(slice.data, 84);
    });

    test('shows error on failure', () async {
      final slice = SignalSlice<int>(useCase: _FailingUseCase(), params: 0);

      final result = await slice.result.nextValue;
      expect(result, isA<Failure<int, AppFailure>>());
      expect(slice.error, isA<NetworkFailure>());
    });

    test('shows empty when data is null but not loading', () async {
      final slice = SignalSlice<int?>(useCase: _NullUseCase(), params: null);

      await slice.result.nextValue;
      expect(slice.isSuccess, true);
      expect(slice.data, null);
    });
  });

  group('ControlledWidget lifecycle', () {
    test('onInit called on widget mount', () {
      var initCalled = false;
      final widget = _TestControlledWidget(
        controller: _FakeController(),
        initCallback: () => initCalled = true,
      );

      // Simulate initState
      widget.onInit();
      expect(initCalled, true);
    });

    test('onDispose called on widget unmount', () {
      var disposeCalled = false;
      final widget = _TestControlledWidget(
        controller: _FakeController(),
        disposeCallback: () => disposeCalled = true,
      );

      widget.onDispose();
      expect(disposeCalled, true);
    });
  });
}

// ── Test doubles ──

class _SlowUseCase extends ZuraffaUseCase<int, int> {
  @override
  SignalResult<int> call(int params, {ZuraffaContext? context}) {
    final sr = SignalResult<int>.initial(
      LoadingResult<int, AppFailure>.loading(),
    );
    Future.delayed(const Duration(milliseconds: 10), () {
      if (!sr.isDisposed) sr.emitSuccess(params * 2);
    });
    return sr;
  }
}

class _FailingUseCase extends ZuraffaUseCase<int, int> {
  @override
  SignalResult<int> call(int params, {ZuraffaContext? context}) {
    final sr = SignalResult<int>.initial(
      LoadingResult<int, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitFailure(const NetworkFailure('network error'));
    });
    return sr;
  }
}

class _NullUseCase extends ZuraffaUseCase<dynamic, int?> {
  @override
  SignalResult<int?> call(dynamic params, {ZuraffaContext? context}) {
    final sr = SignalResult<int?>.initial(
      LoadingResult<int?, AppFailure>.loading(),
    );
    Future.delayed(Duration.zero, () {
      if (!sr.isDisposed) sr.emitSuccess(null);
    });
    return sr;
  }
}

class _FakeController {}

class _TestControlledWidget extends ControlledWidget<_FakeController> {
  _TestControlledWidget({
    required super.controller,
    this.initCallback,
    this.disposeCallback,
  });

  final void Function()? initCallback;
  final void Function()? disposeCallback;

  @override
  void onInit() => initCallback?.call();

  @override
  void onDispose() => disposeCallback?.call();
}
