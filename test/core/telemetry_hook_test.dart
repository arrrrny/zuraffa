import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late HookRegistry registry;

  setUp(() {
    registry = HookRegistry.instance;
    registry.clear();
    registry.isEnabled = true;
  });

  group('TelemetryHook', () {
    test('id is zuraffa-telemetry', () {
      final hook = TelemetryHook();
      expect(hook.id, 'zuraffa-telemetry');
    });

    test('fires on all three phases by default', () {
      final hook = TelemetryHook();
      expect(hook.phases, contains(HookPhase.pre));
      expect(hook.phases, contains(HookPhase.success));
      expect(hook.phases, contains(HookPhase.failure));
      expect(hook.phases.length, 3);
    });

    test('shouldTrigger returns true for all UseCases by default', () {
      final hook = TelemetryHook();
      final ctx = HookContext(
        useCaseName: 'AnyUseCase',
        timestamp: DateTime.now(),
      );

      expect(hook.shouldTrigger(ctx, HookPhase.pre), true);
    });

    test('shouldTrigger returns false for excluded UseCases', () {
      final hook = TelemetryHook(excludeUseCases: {'NoisyUseCase'});

      final excludedCtx = HookContext(
        useCaseName: 'NoisyUseCase',
        timestamp: DateTime.now(),
      );
      final includedCtx = HookContext(
        useCaseName: 'ImportantUseCase',
        timestamp: DateTime.now(),
      );

      expect(hook.shouldTrigger(excludedCtx, HookPhase.pre), false);
      expect(hook.shouldTrigger(includedCtx, HookPhase.pre), true);
    });

    test('shouldTrigger filters to onlyUseCases when non-empty', () {
      final hook = TelemetryHook(
        onlyUseCases: {'GetDealListUseCase', 'CreateBarcodeScanUseCase'},
      );

      final included1 = HookContext(
        useCaseName: 'GetDealListUseCase',
        timestamp: DateTime.now(),
      );
      final included2 = HookContext(
        useCaseName: 'CreateBarcodeScanUseCase',
        timestamp: DateTime.now(),
      );
      final excluded = HookContext(
        useCaseName: 'OtherUseCase',
        timestamp: DateTime.now(),
      );

      expect(hook.shouldTrigger(included1, HookPhase.pre), true);
      expect(hook.shouldTrigger(included2, HookPhase.pre), true);
      expect(hook.shouldTrigger(excluded, HookPhase.pre), false);
    });

    test('excludeUseCases wins over onlyUseCases for same UseCase', () {
      final hook = TelemetryHook(
        onlyUseCases: {'UseCaseA', 'UseCaseB'},
        excludeUseCases: {'UseCaseB'},
      );

      final ctxA = HookContext(
        useCaseName: 'UseCaseA',
        timestamp: DateTime.now(),
      );
      final ctxB = HookContext(
        useCaseName: 'UseCaseB',
        timestamp: DateTime.now(),
      );

      // A is in onlyUseCases and not excluded → fire
      expect(hook.shouldTrigger(ctxA, HookPhase.pre), true);
      // B is in both → exclude wins → don't fire
      expect(hook.shouldTrigger(ctxB, HookPhase.pre), false);
    });

    test('execute does not throw when OTel is not configured', () async {
      // When OTel is not initialized, OtelTracer.startSpan will log a warning
      // but should not crash. The hook must be resilient.
      final hook = TelemetryHook();

      final preCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        metadata: {},
      );

      // Should not throw even without OTel configured
      await hook.execute(preCtx, HookPhase.pre);

      final successCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        duration: Duration(milliseconds: 42),
        metadata: preCtx.metadata,
      );

      await hook.execute(successCtx, HookPhase.success);
    });

    test('execute handles failure phase without throwing', () async {
      final hook = TelemetryHook();

      final preCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        metadata: {},
      );

      await hook.execute(preCtx, HookPhase.pre);

      final failureCtx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        failure: ServerFailure('Server error'),
        metadata: preCtx.metadata,
      );

      await hook.execute(failureCtx, HookPhase.failure);
    });

    test('spanNamePrefix affects span name', () {
      final hook = TelemetryHook(spanNamePrefix: 'custom');
      // We can't easily verify the span name without OTel configured,
      // but we can verify the prefix is stored
      expect(hook.spanNamePrefix, 'custom');
    });

    test('registering TelemetryHook in registry does not crash', () async {
      registry.register(TelemetryHook());

      final ctx = HookContext(
        useCaseName: 'TestUseCase',
        timestamp: DateTime.now(),
        metadata: {},
      );

      // Dispatch all three phases — should not crash
      registry.dispatch(ctx, HookPhase.pre);
      registry.dispatch(ctx, HookPhase.success);
      await Future.delayed(Duration(milliseconds: 50));
    });
  });
}
