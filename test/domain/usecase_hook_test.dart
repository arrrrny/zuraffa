import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// A simple UseCase for testing that returns a value.
class _SuccessUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    return 'result_$params';
  }
}

/// A UseCase that always throws an AppFailure.
class _FailingUseCase extends UseCase<String, String> {
  @override
  Future<String> execute(String params, CancelToken? cancelToken) async {
    throw ServerFailure('Intentional failure');
  }
}

/// A hook that always throws.
class _ThrowingHook extends Hook {
  @override
  final String id = 'thrower';

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    throw Exception('Hook error');
  }
}

/// A hook that records all dispatches.
class _TestHook extends Hook {
  @override
  final String id = 'integration-test';

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

  group('UseCase hook integration', () {
    test('dispatches pre and success on successful UseCase', () async {
      final useCase = _SuccessUseCase();

      await useCase('test_input');

      // Allow fire-and-forget hooks to complete
      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.length, 2);
      expect(hook.calls[0].$2, HookPhase.pre);
      expect(hook.calls[1].$2, HookPhase.success);
    });

    test('pre phase has params but no result', () async {
      final useCase = _SuccessUseCase();

      await useCase('my_param');

      await Future.delayed(Duration(milliseconds: 50));

      final preCall = hook.calls.firstWhere((c) => c.$2 == HookPhase.pre);
      expect(preCall.$1.params, 'my_param');
      expect(preCall.$1.result, isNull);
      expect(preCall.$1.failure, isNull);
      expect(preCall.$1.duration, isNull);
    });

    test('success phase has result and duration', () async {
      final useCase = _SuccessUseCase();

      await useCase('my_param');

      await Future.delayed(Duration(milliseconds: 50));

      final successCall = hook.calls.firstWhere(
        (c) => c.$2 == HookPhase.success,
      );
      expect(successCall.$1.params, 'my_param');
      expect(successCall.$1.result, 'result_my_param');
      expect(successCall.$1.failure, isNull);
      expect(successCall.$1.duration, isNotNull);
    });

    test('useCaseName matches runtime type', () async {
      final useCase = _SuccessUseCase();

      await useCase('test');

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.first.$1.useCaseName, '_SuccessUseCase');
    });

    test('dispatches pre and failure on failed UseCase', () async {
      final useCase = _FailingUseCase();

      await useCase('test_input');

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.length, 2);
      expect(hook.calls[0].$2, HookPhase.pre);
      expect(hook.calls[1].$2, HookPhase.failure);
    });

    test('failure phase has failure but no result', () async {
      final useCase = _FailingUseCase();

      await useCase('my_param');

      await Future.delayed(Duration(milliseconds: 50));

      final failureCall = hook.calls.firstWhere(
        (c) => c.$2 == HookPhase.failure,
      );
      expect(failureCall.$1.params, 'my_param');
      expect(failureCall.$1.result, isNull);
      expect(failureCall.$1.failure, isNotNull);
      expect(failureCall.$1.failure, isA<ServerFailure>());
    });

    test('hook failure does not affect UseCase result', () async {
      HookRegistry.instance.clear();

      final throwingHook = _ThrowingHook();

      HookRegistry.instance.register(throwingHook);
      HookRegistry.instance.register(hook);

      final useCase = _SuccessUseCase();
      final result = await useCase('test');

      await Future.delayed(Duration(milliseconds: 50));

      // UseCase should still succeed
      expect(result.isSuccess, true);

      // Second hook should still fire despite first throwing
      expect(hook.calls.length, 2);
    });

    test('no hooks registered returns normally', () async {
      HookRegistry.instance.clear();

      final useCase = _SuccessUseCase();
      final result = await useCase('test');

      expect(result.isSuccess, true);
    });

    test('disabled registry does not dispatch', () async {
      HookRegistry.instance.isEnabled = false;

      final useCase = _SuccessUseCase();
      await useCase('test');

      await Future.delayed(Duration(milliseconds: 50));

      expect(hook.calls.isEmpty, true);
    });
  });
}
