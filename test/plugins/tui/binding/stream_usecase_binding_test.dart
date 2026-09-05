import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/binding/binding.dart';
import 'package:zuraffa/src/core/cancel_token.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/result.dart';
import 'package:zuraffa/src/domain/stream_usecase.dart';
import 'package:zuraffa/src/domain/usecase.dart';

void main() {
  group('StreamUseCaseBinding (FR-007, SC-004)', () {
    test('A11 / U26: subscribes to a StreamUseCase, propagates each successful '
        'domain value into the screen via onValue, with no developer-written '
        'listener and no TUI-local duplicate store', () async {
      final events = <String>[];
      final useCase = _FakeStreamUseCase<String, String>(
        (params, cancelToken) => Stream.fromIterable(['a', 'b', 'c']),
      );

      final binding = StreamUseCaseBinding<String, String>(
        useCase: useCase,
        params: 'p',
        onValue: events.add,
      );

      binding.start();
      // Give the stream subscription a turn to pump events.
      await Future.delayed(Duration.zero);

      expect(events, ['a', 'b', 'c']);
      expect(binding.value, 'c');
      expect(binding.state.hasFailure, isFalse);

      binding.dispose();
    });

    test(
      'A12: on failure, exposes a renderable failure state while retaining '
      'the last successful value; non-terminal source remains subscribed',
      () async {
        final events = <Object?>[];
        // Raw Stream<String>; stream errors get wrapped as Failure by the
        // StreamUseCase base class.
        final controller = StreamController<String>.broadcast();
        final useCase = _FakeStreamUseCase<String, String>(
          (params, cancelToken) => controller.stream,
        );

        final binding = StreamUseCaseBinding<String, String>(
          useCase: useCase,
          params: 'p',
          onValue: (v) => events.add(v),
          onFailure: (f) => events.add(f),
        );

        binding.start();
        await Future.delayed(Duration.zero);

        // First: success.
        controller.add('first');
        await Future.delayed(Duration.zero);
        expect(binding.value, 'first');
        expect(binding.state.hasFailure, isFalse);

        // Inject an error — the binding should observe a Failure while
        // retaining the last successful value.
        controller.addError(UnknownFailure('boom'));
        await Future.delayed(Duration.zero);
        expect(binding.state.hasFailure, isTrue);
        expect(
          binding.value,
          'first',
          reason: 'last successful value must be retained on failure',
        );
        expect(
          events,
          containsAll(['first', predicate((f) => f is AppFailure)]),
        );

        // FR-007: "a non-terminal source remains subscribed" — we verify this
        // by checking that the binding has not auto-disposed after the
        // failure: its cancel token is still active and dispose() can still
        // be called explicitly.
        expect(
          binding.cancelToken.isCancelled,
          isFalse,
          reason: 'binding must NOT auto-cancel on failure',
        );

        await controller.close();
        binding.dispose();
      },
    );

    test('A13 / U25: on screen disposal, the binding unsubscribes and cancels '
        'any in-flight refresh', () async {
      final controller = StreamController<String>.broadcast();
      var subscribed = false;
      var cancelled = false;
      final useCase = _FakeStreamUseCase<String, String>((params, cancelToken) {
        subscribed = true;
        cancelToken?.onCancel.listen((_) => cancelled = true);
        return controller.stream;
      });

      final binding = StreamUseCaseBinding<String, String>(
        useCase: useCase,
        params: 'p',
      );

      binding.start();
      await Future.delayed(Duration.zero);
      expect(subscribed, isTrue);

      binding.dispose();
      await Future.delayed(Duration.zero);

      expect(
        cancelled,
        isTrue,
        reason: 'dispose MUST cancel the binding\'s CancelToken',
      );
      expect(
        controller.hasListener,
        isFalse,
        reason: 'dispose MUST unsubscribe from the stream',
      );

      await controller.close();
    });

    test('A18: parent CancelToken cancellation propagates to the binding', () {
      final parentToken = CancelToken();
      final useCase = _FakeStreamUseCase<String, String>(
        (params, cancelToken) => const Stream.empty(),
      );

      final binding = StreamUseCaseBinding<String, String>(
        useCase: useCase,
        params: 'p',
        parentCancelToken: parentToken,
      );

      binding.start();
      expect(binding.cancelToken.isCancelled, isFalse);

      // Cancel the parent — the child must follow.
      parentToken.cancel('user quit');
      expect(binding.cancelToken.isCancelled, isTrue);
    });
  });

  group('UseCaseResultBinding (FR-007, U28)', () {
    test('A11: refresh() invokes the UseCase and propagates the result; the '
        'state transitions initial → inFlight → value', () async {
      final useCase = _FakeUseCase<int, String>(
        (params, cancelToken) async => const Success(42),
      );

      final events = <int>[];
      final binding = UseCaseResultBinding<int, String>(
        useCase: useCase,
        params: 'p',
        onValue: events.add,
      );

      expect(binding.state.isInitial, isTrue);

      await binding.mount();

      expect(events, [42]);
      expect(binding.value, 42);
      expect(binding.state.isInFlight, isFalse);
      expect(binding.state.hasFailure, isFalse);
    });

    test('A12: failure retains the last successful value', () async {
      var callCount = 0;
      final useCase = _FakeUseCase<int, String>((params, cancelToken) async {
        callCount++;
        if (callCount == 1) return const Success(100);
        return Failure(UnknownFailure('refresh failed'));
      });

      final binding = UseCaseResultBinding<int, String>(
        useCase: useCase,
        params: 'p',
      );

      await binding.mount();
      expect(binding.value, 100);
      expect(binding.state.hasFailure, isFalse);

      await binding.refresh();
      expect(binding.value, 100, reason: 'last value retained on failure');
      expect(binding.state.hasFailure, isTrue);
      expect(binding.state.failure, isA<UnknownFailure>());
    });
  });

  group('RepositoryBinding (FR-007, U27)', () {
    test('observes a repository stream / notifier', () async {
      final events = <int>[];
      final controller = StreamController<int>.broadcast();
      final binding = RepositoryBinding<int>(
        source: (cancelToken) => controller.stream,
        onValue: events.add,
      );

      await binding.mount();
      controller.add(1);
      controller.add(2);
      await Future.delayed(Duration.zero);

      expect(events, [1, 2]);
      expect(binding.value, 2);

      binding.dispose();
      expect(controller.hasListener, isFalse);
      await controller.close();
    });
  });
}

/// A minimal fake [StreamUseCase] that delegates to a function returning a
/// `Stream<T>` (matching the base class's `execute` signature).
class _FakeStreamUseCase<T, P> extends StreamUseCase<T, P> {
  _FakeStreamUseCase(this._fn);

  final Stream<T> Function(P params, CancelToken? cancelToken) _fn;

  @override
  Stream<T> execute(P params, CancelToken? cancelToken) {
    return _fn(params, cancelToken);
  }
}

/// A minimal fake [UseCase] that delegates to an async function returning
/// a [Result] (so we can simulate Success and Failure paths uniformly).
class _FakeUseCase<T, P> extends UseCase<T, P> {
  _FakeUseCase(this._fn);

  final Future<Result<T, AppFailure>> Function(
    P params,
    CancelToken? cancelToken,
  )
  _fn;

  @override
  Future<T> execute(P params, CancelToken? cancelToken) async {
    final result = await _fn(params, cancelToken);
    return result.fold((value) => value, (failure) => throw failure);
  }
}
