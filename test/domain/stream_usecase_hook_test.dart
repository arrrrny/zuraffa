import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// A simple StreamUseCase that emits a few values then completes.
class _StreamSuccessUseCase extends StreamUseCase<String, int> {
  @override
  Stream<String> execute(int count, CancelToken? cancelToken) async* {
    for (var i = 0; i < count; i++) {
      yield 'value_$i';
    }
  }
}

/// A StreamUseCase that throws an AppFailure when executed.
class _StreamFailingUseCase extends StreamUseCase<String, int> {
  @override
  Stream<String> execute(int count, CancelToken? cancelToken) {
    throw ServerFailure('Stream intentional failure');
  }
}

/// A hook that records all dispatches.
class _TestHook extends Hook {
  @override
  final String id = 'stream-integration-test';

  final List<(HookContext, HookPhase)> calls = [];

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    calls.add((context, phase));
  }
}

void main() {
  late _TestHook hook;

  setUp(() {
    hook = _TestHook();
    HookRegistry.instance.clear();
    HookRegistry.instance.isEnabled = true;
    HookRegistry.instance.register(hook);
  });

  tearDown(() {
    HookRegistry.instance.clear();
  });

  group('StreamUseCase hook integration', () {
    test('dispatches pre and success on completed stream', () async {
      final useCase = _StreamSuccessUseCase();

      await useCase(3).last;

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.length, 2);
      expect(hook.calls[0].$2, HookPhase.pre);
      expect(hook.calls[1].$2, HookPhase.success);
    });

    test('pre phase has params but no result', () async {
      final useCase = _StreamSuccessUseCase();

      await useCase(2).last;

      await Future.delayed(Duration(milliseconds: 50));

      final preCall = hook.calls.firstWhere((c) => c.$2 == HookPhase.pre);
      expect(preCall.$1.params, 2);
      expect(preCall.$1.result, isNull);
      expect(preCall.$1.duration, isNull);
    });

    test('success phase has duration', () async {
      final useCase = _StreamSuccessUseCase();

      await useCase(2).last;

      await Future.delayed(Duration(milliseconds: 50));

      final successCall = hook.calls.firstWhere(
        (c) => c.$2 == HookPhase.success,
      );
      expect(successCall.$1.duration, isNotNull);
    });

    test('useCaseName matches runtime type', () async {
      final useCase = _StreamSuccessUseCase();

      await useCase(1).last;

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.first.$1.useCaseName, '_StreamSuccessUseCase');
    });

    test('dispatches pre and failure on failed stream', () async {
      final useCase = _StreamFailingUseCase();

      // Consume the stream to trigger the failure
      await for (final _ in useCase(1)) {}

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.length, 2);
      expect(hook.calls[0].$2, HookPhase.pre);
      expect(hook.calls[1].$2, HookPhase.failure);
    });

    test('failure phase has failure but no result', () async {
      final useCase = _StreamFailingUseCase();

      await for (final _ in useCase(1)) {}

      await Future.delayed(Duration(milliseconds: 50));

      final failureCall = hook.calls.firstWhere(
        (c) => c.$2 == HookPhase.failure,
      );
      expect(failureCall.$1.failure, isNotNull);
      expect(failureCall.$1.failure, isA<ServerFailure>());
      expect(failureCall.$1.result, isNull);
    });

    test('hook fires once for pre regardless of stream length', () async {
      final useCase = _StreamSuccessUseCase();

      await useCase(5).last;

      await Future.delayed(Duration(milliseconds: 50));

      // Only one pre and one success, not 5
      final preCalls = hook.calls.where((c) => c.$2 == HookPhase.pre);
      final successCalls = hook.calls.where((c) => c.$2 == HookPhase.success);
      expect(preCalls.length, 1);
      expect(successCalls.length, 1);
    });

    test('no hooks registered returns normally', () async {
      HookRegistry.instance.clear();

      final useCase = _StreamSuccessUseCase();
      final result = await useCase(1).first;

      expect(result.isSuccess, true);
      expect(result.getOrThrow(), 'value_0');
    });

    test('disabled registry does not dispatch', () async {
      HookRegistry.instance.isEnabled = false;

      final useCase = _StreamSuccessUseCase();
      await useCase(1).last;

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.isEmpty, true);
    });
  });
}
