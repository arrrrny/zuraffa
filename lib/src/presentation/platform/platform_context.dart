import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'device_class.dart';
import 'platform_class.dart';

/// Immutable runtime description used by adaptive layout and shell resolution.
@immutable
class PlatformContext {
  final PlatformClass platformClass;
  final DeviceClass deviceClass;

  const PlatformContext({
    required this.platformClass,
    required this.deviceClass,
  });

  factory PlatformContext.current({
    required DeviceClass deviceClass,
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    return PlatformContext(
      platformClass: PlatformClass.current(
        targetPlatform: targetPlatform,
        isWeb: isWeb,
      ),
      deviceClass: deviceClass,
    );
  }

  String get platformKey => platformClass.layoutKey;

  String get deviceKey => deviceClass.layoutKey;

  String get compoundKey => '${platformKey}_${deviceKey}';

  @override
  String toString() =>
      'PlatformContext(platform: $platformKey, device: $deviceKey)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformContext &&
            other.platformClass == platformClass &&
            other.deviceClass == deviceClass;
  }

  @override
  int get hashCode => Object.hash(platformClass, deviceClass);
}
