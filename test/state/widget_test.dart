import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SignalBuilder', () {
    testWidgets('renders initial value and rebuilds on change', (tester) async {
      final signal = Signal<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder<int>(
            signal: signal,
            builder: (context, value) => Text('value: $value'),
          ),
        ),
      );

      expect(find.text('value: 0'), findsOneWidget);

      signal.value = 42;
      await tester.pump();
      expect(find.text('value: 42'), findsOneWidget);
      expect(find.text('value: 0'), findsNothing);
    });

    testWidgets('does not rebuild after unmount', (tester) async {
      final signal = Signal<int>(0);
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SignalBuilder<int>(
            signal: signal,
            builder: (context, value) {
              builds++;
              return Text('value: $value');
            },
          ),
        ),
      );
      expect(builds, 1);

      // Unmount: subscription must be cancelled so no setState-after-dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      signal.value = 1;
      await tester.pump();

      expect(builds, 1);
    });
  });

  group('SignalSubscription', () {
    test('cancels subscription on dispose', () {
      final signal = Signal<String>('a');
      var canceledCalls = 0;
      final sub = signal.listen((_) => canceledCalls++);
      expect(canceledCalls, 1); // eager initial delivery

      sub.cancel();
      signal.value = 'b';

      // Listener must NOT be invoked after cancellation.
      expect(canceledCalls, 1);
    });
  });

  group('FragmentBuilder', () {
    testWidgets('shows loading then data', (tester) async {
      final slice = SignalSlice<int>(useCase: _SlowUseCase(), params: 42);

      await tester.pumpWidget(
        MaterialApp(
          home: FragmentBuilder<int>(
            slice: slice,
            onLoading: (context) => const Text('loading...'),
            builder: (context, data) => Text('data: $data'),
          ),
        ),
      );

      expect(find.text('loading...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('data: 84'), findsOneWidget);
    });

    testWidgets('shows error on failure', (tester) async {
      final slice = SignalSlice<int>(useCase: _FailingUseCase(), params: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: FragmentBuilder<int>(
            slice: slice,
            onError: (context, error) => Text('error: ${error.message}'),
            builder: (context, data) => Text('data: $data'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.textContaining('error:'), findsOneWidget);
    });

    testWidgets('re-subscribes when slice changes', (tester) async {
      final sliceA = SignalSlice<int>(useCase: _SlowUseCase(), params: 10);
      final sliceB = SignalSlice<int>(useCase: _SlowUseCase(), params: 20);

      Widget build(SignalSlice<int> slice) {
        return MaterialApp(
          home: FragmentBuilder<int>(
            slice: slice,
            builder: (context, data) => Text('data: $data'),
          ),
        );
      }

      await tester.pumpWidget(build(sliceA));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('data: 20'), findsOneWidget); // sliceA yields 20

      // Swap to sliceB; didUpdateWidget must re-subscribe.
      await tester.pumpWidget(build(sliceB));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('data: 40'), findsOneWidget);
      expect(find.text('data: 20'), findsNothing);
    });
  });

  group('ControlledWidget', () {
    testWidgets('calls onInit on mount and renders build output', (
      tester,
    ) async {
      var initCalled = false;
      var disposeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: _TestControlledWidget(
            controller: _FakeController(),
            initCallback: () => initCalled = true,
            disposeCallback: () => disposeCalled = true,
          ),
        ),
      );

      expect(initCalled, true);
      expect(find.text('hello from controller'), findsOneWidget);

      // Unmount → onDispose fires.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
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

class _FakeController {
  String get greeting => 'hello from controller';
}

class _TestControlledWidget extends ControlledWidget<_FakeController> {
  const _TestControlledWidget({
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

  @override
  Widget build(BuildContext context) {
    return Text(controller.greeting);
  }
}
