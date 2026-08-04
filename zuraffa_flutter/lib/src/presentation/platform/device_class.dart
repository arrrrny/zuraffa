import 'package:meta/meta.dart';

/// High-level device categories used by adaptive layout resolution.
enum DeviceClass {
  watch('watch'),
  phone('mobile'),
  tablet('tablet'),
  desktop('desktop');

  const DeviceClass(this.layoutKey);

  /// Canonical layout key used by generated scaffolds and fallback lookup.
  final String layoutKey;

  bool get isDesktopLike => this == DeviceClass.desktop;

  bool get isHandheld => this == DeviceClass.phone || this == DeviceClass.watch;

  static DeviceClass fromWidth(double width) {
    if (width < 300) return DeviceClass.watch;
    if (width < 600) return DeviceClass.phone;
    if (width < 950) return DeviceClass.tablet;
    return DeviceClass.desktop;
  }
}

@visibleForTesting
const List<String> defaultAdaptiveLayoutTargets = <String>[
  'mobile',
  'tablet',
  'desktop',
  'macos',
];
