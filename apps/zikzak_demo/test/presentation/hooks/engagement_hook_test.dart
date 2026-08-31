import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zikzak_demo/src/data/engagement_event_repository.dart';
import 'package:zikzak_demo/src/domain/engagement_event.dart';
import 'package:zikzak_demo/src/domain/usecases/engagement_usecases.dart';
import 'package:zikzak_demo/src/presentation/hooks/engagement_hook.dart';

/// Spies on the built-in TelemetryHook while keeping its behaviour intact,
/// so C4 can prove both hooks fire independently on the same execution.
class _SpyTelemetryHook extends TelemetryHook {
  int preCount = 0;
  int successCount = 0;
  int failureCount = 0;

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    switch (phase) {
      case HookPhase.pre:
        preCount++;
        break;
      case HookPhase.success:
        successCount++;
        break;
      case HookPhase.failure:
        failureCount++;
        break;
    }
    return super.execute(context, phase);
  }
}

void main() {
  late Directory hiveDir;
  late EngagementEventRepository repository;

  setUp(() async {
    HookRegistry.instance.clear();
    HookRegistry.instance.isEnabled = true;
    hiveDir = await Directory.systemTemp.createTemp('zikzak_hook_test');
    repository = EngagementEventRepository();
    await repository.init(path: hiveDir.path);
  });

  tearDown(() async {
    HookRegistry.instance.clear();
    await repository.dispose();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  Future<EngagementHook> registerHook() async {
    final hook = EngagementHook(repository);
    HookRegistry.instance.register(hook);
    return hook;
  }

  group('EngagementHook — spec 011 US3', () {
    test(
      'C1: barcode scan success stores EngagementEvent(BARCODE_SCAN)',
      () async {
        await registerHook();
        final useCase = CreateBarcodeScanUseCase();

        final result = await useCase('4006381333931');
        await pumpEventQueue();

        expect(result.isSuccess, isTrue);
        final events = await repository.getAll();
        expect(events, hasLength(1));
        expect(events.single.type, EngagementEventType.BARCODE_SCAN);
        expect(events.single.payload, '4006381333931');
        expect(
          events.single.synced,
          isFalse,
          reason: 'queued for background sync',
        );
      },
    );

    test('C2: search success stores EngagementEvent(SEARCH_TERM)', () async {
      await registerHook();
      final useCase = SearchProductsUseCase();

      final result = await useCase('zikzak pro');
      await pumpEventQueue();

      expect(result.isSuccess, isTrue);
      final events = await repository.getAll();
      expect(events, hasLength(1));
      expect(events.single.type, EngagementEventType.SEARCH_TERM);
      expect(events.single.payload, 'zikzak pro');
    });

    test('C3: failing tracked UseCase creates NO engagement event', () async {
      await registerHook();
      final useCase = CreateBarcodeScanUseCase();

      final result = await useCase('');
      await pumpEventQueue();

      expect(result.isFailure, isTrue);
      expect(await repository.count(), 0);
    });

    test('C4: TelemetryHook and EngagementHook fire independently', () async {
      final telemetry = _SpyTelemetryHook();
      HookRegistry.instance.register(telemetry);
      await registerHook();
      final useCase = CreateBarcodeScanUseCase();

      final result = await useCase('4006381333931');
      await pumpEventQueue();

      // UseCase result is unaffected by either hook.
      expect(result.isSuccess, isTrue);

      // EngagementHook fired: exactly one engagement event stored.
      final events = await repository.getAll();
      expect(events, hasLength(1));
      expect(events.single.type, EngagementEventType.BARCODE_SCAN);

      // TelemetryHook fired through the same dispatch, independently.
      expect(telemetry.preCount, 1);
      expect(telemetry.successCount, 1);
      expect(telemetry.failureCount, 0);
    });

    test('hook maps all eight engagement UseCases (SC-005)', () {
      const map = EngagementHook.useCaseEventMap;
      expect(map, hasLength(8));
      expect(
        map.values.toSet(),
        equals(EngagementEventType.values.toSet()),
        reason: 'every EngagementEventType must be reachable',
      );
    });
  });
}
