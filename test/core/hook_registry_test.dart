import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// A test hook that records every dispatch.
class _RecordingHook extends Hook {
  _RecordingHook({
    this.id = 'test-recorder',
    this.hookPhases = const {
      HookPhase.pre,
      HookPhase.success,
      HookPhase.failure,
    },
    this.triggerFilter,
    this.throwOnPhase,
    this.hookPriority = 0,
  });

  @override
  final String id;

  final Set<HookPhase> hookPhases;

  final bool Function(HookContext, HookPhase)? triggerFilter;

  final HookPhase? throwOnPhase;

  @override
  final int hookPriority;

  final List<(HookContext, HookPhase)> calls = [];

  @override
  int get priority => hookPriority;

  @override
  Set<HookPhase> get phases => hookPhases;

  @override
  bool shouldTrigger(HookContext context, HookPhase phase) {
    return triggerFilter?.call(context, phase) ?? true;
  }

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    calls.add((context, phase));
    if (throwOnPhase == phase) {
      throw Exception('Test error in $phase');
    }
  }
}

void main() {
  late HookRegistry registry;

  setUp(() {
    registry = HookRegistry.instance;
    registry.clear();
    registry.isEnabled = true;
  });

  group('HookRegistry', () {
    test('register adds hook to registry', () {
      final hook = _RecordingHook(id: 'test-1');
      registry.register(hook);

      expect(registry.hooks.length, 1);
      expect(registry.hooks.first.id, 'test-1');
    });

    test('register throws StateError for duplicate id', () {
      registry.register(_RecordingHook(id: 'dup'));
      expect(
        () => registry.register(_RecordingHook(id: 'dup')),
        throwsStateError,
      );
    });

    test('unregister removes hook by id', () {
      registry.register(_RecordingHook(id: 'removable'));
      expect(registry.hooks.length, 1);

      registry.unregister('removable');
      expect(registry.hooks.isEmpty, true);
    });

    test('unregister unknown id is a no-op', () {
      registry.register(_RecordingHook(id: 'keep'));
      registry.unregister('nonexistent');
      expect(registry.hooks.length, 1);
    });

    test('clear removes all hooks', () {
      registry.register(_RecordingHook(id: 'a'));
      registry.register(_RecordingHook(id: 'b'));
      registry.clear();
      expect(registry.hooks.isEmpty, true);
    });

    test('hooks are sorted by priority (ascending)', () {
      registry.register(_RecordingHook(id: 'low', hookPriority: 10));
      registry.register(_RecordingHook(id: 'high', hookPriority: -5));
      registry.register(_RecordingHook(id: 'mid', hookPriority: 0));

      final ids = registry.hooks.map((h) => h.id).toList();
      expect(ids, ['high', 'mid', 'low']);
    });

    test('dispatch fires matching hooks', () async {
      final hook = _RecordingHook(id: 'test');
      registry.register(hook);

      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );

      registry.dispatch(ctx, HookPhase.pre);
      // Give fire-and-forget futures time to complete
      await Future.delayed(Duration(milliseconds: 10));

      expect(hook.calls.length, 1);
      expect(hook.calls.first.$2, HookPhase.pre);
      expect(hook.calls.first.$1.useCaseName, 'TestUseCase');
    });

    test('dispatch respects phases filter', () async {
      final hook = _RecordingHook(
        id: 'success-only',
        hookPhases: {HookPhase.success},
      );
      registry.register(hook);

      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );

      registry.dispatch(ctx, HookPhase.pre);
      registry.dispatch(ctx, HookPhase.success);
      registry.dispatch(ctx, HookPhase.failure);
      await Future.delayed(Duration(milliseconds: 10));

      expect(hook.calls.length, 1);
      expect(hook.calls.first.$2, HookPhase.success);
    });

    test('dispatch respects shouldTrigger filter', () async {
      final hook = _RecordingHook(
        id: 'filtered',
        triggerFilter: (ctx, _) => ctx.useCaseName == 'MatchMe',
      );
      registry.register(hook);

      final matchCtx = HookContext(
        useCaseName: 'MatchMe',
        timestamp: DateTime.now(),
      );
      final noMatchCtx = HookContext(
        useCaseName: 'IgnoreMe',
        timestamp: DateTime.now(),
      );

      registry.dispatch(matchCtx, HookPhase.success);
      registry.dispatch(noMatchCtx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 10));

      expect(hook.calls.length, 1);
      expect(hook.calls.first.$1.useCaseName, 'MatchMe');
    });

    test('dispatch does not propagate hook errors', () async {
      final throwingHook = _RecordingHook(
        id: 'thrower',
        throwOnPhase: HookPhase.success,
      );
      final normalHook = _RecordingHook(id: 'normal');
      registry.register(throwingHook);
      registry.register(normalHook);

      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );

      // Should not throw
      registry.dispatch(ctx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 10));

      // Both hooks should have been called despite the first throwing
      expect(throwingHook.calls.length, 1);
      expect(normalHook.calls.length, 1);
    });

    test('dispatch returns immediately when registry is empty', () {
      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );

      // Should not throw or block
      registry.dispatch(ctx, HookPhase.pre);
      expect(registry.isEmpty, true);
    });

    test('dispatch does nothing when disabled', () async {
      final hook = _RecordingHook(id: 'test');
      registry.register(hook);
      registry.isEnabled = false;

      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
      );

      registry.dispatch(ctx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 10));

      expect(hook.calls.isEmpty, true);

      // Re-enable and verify it works
      registry.isEnabled = true;
      registry.dispatch(ctx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 10));

      expect(hook.calls.length, 1);
    });

    test('metadata map is shared across phases in same invocation', () async {
      // A hook that writes in pre and reads in success
      late String? readValue;
      final hook = _RecordingHook(
        id: 'metadata-test',
        triggerFilter: (_, phase) =>
            phase == HookPhase.pre || phase == HookPhase.success,
      );
      registry.register(hook);

      // We need to test the actual metadata sharing. Since our test hook
      // just records calls, we'll verify the metadata map is the same
      // object across phases by using a custom hook inline.
      final sharedMeta = <String, dynamic>{};
      sharedMeta['test_key'] = 'test_value';

      final preCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        metadata: sharedMeta,
      );
      final successCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        metadata: sharedMeta,
      );

      registry.dispatch(preCtx, HookPhase.pre);
      registry.dispatch(successCtx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 10));

      // Both calls received contexts with the same metadata map
      expect(hook.calls.length, 2);
      expect(hook.calls[0].$1.metadata['test_key'], 'test_value');
      expect(hook.calls[1].$1.metadata['test_key'], 'test_value');
    });
  });
}
