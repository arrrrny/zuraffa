/// Device + environment seam: platform/device info, connectivity, power,
/// and app lifecycle as typed snapshots the fetch/otel core already
/// wants (the analysis §4 `device` built-in).
library;

/// The network connectivity state.
enum ConnectivityState { offline, wifi, cellular, ethernet, unknown }

/// The power source.
enum BatteryState { full, charging, unplugged, unknown }

/// Where the app is in its lifecycle.
enum AppLifecycleState2 { resumed, inactive, paused, detached, unknown }

/// Immutable device/environment snapshot.
class DeviceInfo {
  /// Operating system (android, ios, macos, linux, windows, web).
  final String platform;

  /// OS version string.
  final String osVersion;

  /// Device model name.
  final String model;

  /// App's current version.
  final String appVersion;

  /// Locale identifier (e.g. en_US).
  final String locale;

  const DeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.model,
    required this.appVersion,
    required this.locale,
  });

  static const DeviceInfo unknown = DeviceInfo(
    platform: 'unknown',
    osVersion: 'unknown',
    model: 'unknown',
    appVersion: 'unknown',
    locale: 'unknown',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          other.platform == platform &&
          other.osVersion == osVersion &&
          other.model == model &&
          other.appVersion == appVersion &&
          other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(platform, osVersion, model, appVersion, locale);
}

/// Live connectivity + power reading.
class DeviceStatus {
  /// Current connectivity.
  final ConnectivityState connectivity;

  /// Whether the network is metered (cellular/hotspot).
  final bool metered;

  /// Battery charge fraction [0..1]; null when unknown/unreadable.
  final double? batteryLevel;

  /// Charging state.
  final BatteryState battery;

  const DeviceStatus({
    this.connectivity = ConnectivityState.unknown,
    this.metered = false,
    this.batteryLevel,
    this.battery = BatteryState.unknown,
  });

  /// Whether the device is online per [connectivity].
  bool get isOnline =>
      connectivity == ConnectivityState.wifi ||
      connectivity == ConnectivityState.cellular ||
      connectivity == ConnectivityState.ethernet;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceStatus &&
          other.connectivity == connectivity &&
          other.metered == metered &&
          other.batteryLevel == batteryLevel &&
          other.battery == battery;

  @override
  int get hashCode => Object.hash(connectivity, metered, batteryLevel, battery);
}

/// The device contract.
abstract class DevicePort {
  /// Static device/environment info (cached by adapters).
  Future<DeviceInfo> info();

  /// Current connectivity + power status.
  Future<DeviceStatus> status();

  /// The current app lifecycle state.
  AppLifecycleState2 get lifecycle;

  /// Subscribes to lifecycle changes; returns an unsubscribe function.
  void Function() onLifecycleChanged(
    void Function(AppLifecycleState2 state) listener,
  );
}

/// Pure-Dart default adapter (test/dev): scriptable status + lifecycle.
class InMemoryDeviceAdapter implements DevicePort {
  /// The info [info()] reports.
  DeviceInfo deviceInfo;

  /// The status [status()] reports.
  DeviceStatus deviceStatus;

  @override
  AppLifecycleState2 lifecycle = AppLifecycleState2.resumed;

  final List<void Function(AppLifecycleState2 state)> _listeners = [];

  InMemoryDeviceAdapter({
    this.deviceInfo = DeviceInfo.unknown,
    this.deviceStatus = const DeviceStatus(),
  });

  @override
  Future<DeviceInfo> info() async => deviceInfo;

  @override
  Future<DeviceStatus> status() async => deviceStatus;

  @override
  void Function() onLifecycleChanged(
    void Function(AppLifecycleState2 state) listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Simulates a lifecycle transition (the OS callback).
  void emitLifecycle(AppLifecycleState2 state) {
    lifecycle = state;
    for (final listener in List.of(_listeners)) {
      listener(state);
    }
  }
}
