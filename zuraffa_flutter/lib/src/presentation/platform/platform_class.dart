import 'package:flutter/foundation.dart';

/// Runtime platform categories used by adaptive layout resolution.
enum PlatformClass {
  ios('ios'),
  android('android'),
  macos('macos'),
  windows('windows'),
  linux('linux'),
  web('web'),
  unknown('default');

  const PlatformClass(this.layoutKey);

  /// Canonical layout key used by generated scaffolds and fallback lookup.
  final String layoutKey;

  bool get isDesktopLike => switch (this) {
    PlatformClass.macos ||
    PlatformClass.windows ||
    PlatformClass.linux ||
    PlatformClass.web => true,
    PlatformClass.ios ||
    PlatformClass.android ||
    PlatformClass.unknown => false,
  };

  static PlatformClass current({
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    if (isWeb) {
      return PlatformClass.web;
    }

    switch (targetPlatform ?? defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return PlatformClass.ios;
      case TargetPlatform.android:
        return PlatformClass.android;
      case TargetPlatform.macOS:
        return PlatformClass.macos;
      case TargetPlatform.windows:
        return PlatformClass.windows;
      case TargetPlatform.linux:
        return PlatformClass.linux;
      case TargetPlatform.fuchsia:
        return PlatformClass.unknown;
    }
  }
}
