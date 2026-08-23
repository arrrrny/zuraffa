import 'package:get_it/get_it.dart';

import 'device.dart';

export 'device.dart';

/// App-facing device facade.
///
/// ```dart
/// final device = DeviceService();
/// final info = await device.info();
/// final online = (await device.status()).isOnline;
/// device.onAppLifecycle((state) { /* cache flush on paused */ });
/// ```
class DeviceService {
  /// The platform adapter (or the in-memory default in tests).
  final DevicePort port;

  DeviceService({DevicePort? port}) : port = port ?? InMemoryDeviceAdapter();

  /// Static device/environment info.
  Future<DeviceInfo> info() => port.info();

  /// Current connectivity + power status.
  Future<DeviceStatus> status() => port.status();

  /// Whether the device is currently online.
  Future<bool> get isOnline async => (await port.status()).isOnline;

  /// The current app lifecycle state.
  AppLifecycleState2 get lifecycle => port.lifecycle;

  /// Subscribes to lifecycle changes; returns the unsubscribe function.
  void Function() onAppLifecycle(
    void Function(AppLifecycleState2 state) listener,
  ) => port.onLifecycleChanged(listener);
}

/// Registers the device stack onto [getIt].
void registerDeviceDependencies(GetIt getIt, {DevicePort? port}) {
  getIt
    ..registerLazySingleton<DevicePort>(() => port ?? InMemoryDeviceAdapter())
    ..registerLazySingleton<DeviceService>(
      () => DeviceService(port: getIt<DevicePort>()),
    );
}
