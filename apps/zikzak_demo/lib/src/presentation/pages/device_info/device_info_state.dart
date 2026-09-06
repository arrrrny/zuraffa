// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/device_info/device_info.dart';

class DeviceInfoState {
  const DeviceInfoState({
    this.error,
    this.deviceInfo,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single DeviceInfo entity
  final DeviceInfo? deviceInfo;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  DeviceInfoState copyWith({
    AppFailure? error,
    DeviceInfo? deviceInfo,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => DeviceInfoState(
    error: error ?? this.error,
    deviceInfo: deviceInfo ?? this.deviceInfo,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoState &&
          other.error == error &&
          other.deviceInfo == deviceInfo &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      deviceInfo.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'DeviceInfoState(error: $error, deviceInfo: $deviceInfo)';
}

// END GENERATED
