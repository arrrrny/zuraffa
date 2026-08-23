import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Device built-in: snapshot values, status semantics, lifecycle events,
/// and DI wiring.
void main() {
  group('DeviceInfo / DeviceStatus', () {
    test('equality covers every field', () {
      const a = DeviceInfo(
        platform: 'android',
        osVersion: '15',
        model: 'Pixel 9',
        appVersion: '2.1.0',
        locale: 'en_US',
      );
      const b = DeviceInfo(
        platform: 'android',
        osVersion: '15',
        model: 'Pixel 9',
        appVersion: '2.1.0',
        locale: 'en_US',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWithNothing(), isTrue);
    });

    test('isOnline is true only for wifi/cellular/ethernet', () {
      expect(
        const DeviceStatus(connectivity: ConnectivityState.wifi).isOnline,
        isTrue,
      );
      expect(
        const DeviceStatus(connectivity: ConnectivityState.cellular).isOnline,
        isTrue,
      );
      expect(
        const DeviceStatus(connectivity: ConnectivityState.ethernet).isOnline,
        isTrue,
      );
      expect(
        const DeviceStatus(connectivity: ConnectivityState.offline).isOnline,
        isFalse,
      );
      expect(
        const DeviceStatus(connectivity: ConnectivityState.unknown).isOnline,
        isFalse,
      );
    });
  });

  group('InMemoryDeviceAdapter', () {
    test('reports the scripted info and status', () async {
      final port = InMemoryDeviceAdapter(
        deviceInfo: const DeviceInfo(
          platform: 'ios',
          osVersion: '18.1',
          model: 'iPhone 17',
          appVersion: '1.0.0',
          locale: 'tr_TR',
        ),
        deviceStatus: const DeviceStatus(
          connectivity: ConnectivityState.cellular,
          metered: true,
          batteryLevel: 0.42,
          battery: BatteryState.charging,
        ),
      );

      expect((await port.info()).model, 'iPhone 17');
      final status = await port.status();
      expect(status.connectivity, ConnectivityState.cellular);
      expect(status.metered, isTrue);
      expect(status.batteryLevel, 0.42);
      expect(status.battery, BatteryState.charging);
    });

    test('lifecycle listeners fire and unsubscribe cleanly', () {
      final port = InMemoryDeviceAdapter();
      final seen = <AppLifecycleState2>[];

      final unsubscribe = port.onLifecycleChanged(seen.add);
      port.emitLifecycle(AppLifecycleState2.paused);
      port.emitLifecycle(AppLifecycleState2.resumed);
      expect(seen, [AppLifecycleState2.paused, AppLifecycleState2.resumed]);
      expect(port.lifecycle, AppLifecycleState2.resumed);

      unsubscribe();
      port.emitLifecycle(AppLifecycleState2.detached);
      expect(seen, hasLength(2), reason: 'unsubscribed listeners stay quiet');
    });
  });

  group('DeviceService + DI', () {
    test('facade surfaces info/status/isOnline/lifecycle', () async {
      final port = InMemoryDeviceAdapter(
        deviceStatus: const DeviceStatus(connectivity: ConnectivityState.wifi),
      );
      final service = DeviceService(port: port);

      expect(await service.isOnline, isTrue);
      expect(service.lifecycle, AppLifecycleState2.resumed);

      final events = <AppLifecycleState2>[];
      final unsubscribe = service.onAppLifecycle(events.add);
      port.emitLifecycle(AppLifecycleState2.inactive);
      expect(events, [AppLifecycleState2.inactive]);
      unsubscribe();
    });

    test('registerDeviceDependencies wires the stack with injection', () async {
      final getIt = GetIt.asNewInstance();
      final custom = InMemoryDeviceAdapter(
        deviceStatus: const DeviceStatus(
          connectivity: ConnectivityState.offline,
        ),
      );
      registerDeviceDependencies(getIt, port: custom);

      final service = getIt<DeviceService>();
      expect(
        await service.isOnline,
        isFalse,
        reason: 'the injected adapter backs the service',
      );
    });
  });
}

extension on DeviceInfo {
  DeviceInfo copyWithNothing() => this;
}
