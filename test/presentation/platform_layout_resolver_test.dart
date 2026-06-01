import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/presentation/platform/device_class.dart';
import 'package:zuraffa/src/presentation/platform/platform_class.dart';
import 'package:zuraffa/src/presentation/platform/platform_context.dart';
import 'package:zuraffa/src/presentation/platform/platform_layout_resolver.dart';

void main() {
  group('DeviceClass', () {
    test('fromWidth returns correct device class', () {
      expect(DeviceClass.fromWidth(100), DeviceClass.watch);
      expect(DeviceClass.fromWidth(299), DeviceClass.watch);
      expect(DeviceClass.fromWidth(300), DeviceClass.phone);
      expect(DeviceClass.fromWidth(599), DeviceClass.phone);
      expect(DeviceClass.fromWidth(600), DeviceClass.tablet);
      expect(DeviceClass.fromWidth(949), DeviceClass.tablet);
      expect(DeviceClass.fromWidth(950), DeviceClass.desktop);
      expect(DeviceClass.fromWidth(1920), DeviceClass.desktop);
    });

    test('layoutKey returns canonical keys', () {
      expect(DeviceClass.watch.layoutKey, 'watch');
      expect(DeviceClass.phone.layoutKey, 'mobile');
      expect(DeviceClass.tablet.layoutKey, 'tablet');
      expect(DeviceClass.desktop.layoutKey, 'desktop');
    });

    test('isDesktopLike and isHandheld', () {
      expect(DeviceClass.desktop.isDesktopLike, isTrue);
      expect(DeviceClass.phone.isDesktopLike, isFalse);
      expect(DeviceClass.phone.isHandheld, isTrue);
      expect(DeviceClass.watch.isHandheld, isTrue);
      expect(DeviceClass.desktop.isHandheld, isFalse);
      expect(DeviceClass.tablet.isHandheld, isFalse);
    });
  });

  group('PlatformClass', () {
    test('layoutKey returns canonical keys', () {
      expect(PlatformClass.ios.layoutKey, 'ios');
      expect(PlatformClass.android.layoutKey, 'android');
      expect(PlatformClass.macos.layoutKey, 'macos');
      expect(PlatformClass.windows.layoutKey, 'windows');
      expect(PlatformClass.linux.layoutKey, 'linux');
      expect(PlatformClass.web.layoutKey, 'web');
    });

    test('isDesktopLike', () {
      expect(PlatformClass.macos.isDesktopLike, isTrue);
      expect(PlatformClass.windows.isDesktopLike, isTrue);
      expect(PlatformClass.linux.isDesktopLike, isTrue);
      expect(PlatformClass.web.isDesktopLike, isTrue);
      expect(PlatformClass.ios.isDesktopLike, isFalse);
      expect(PlatformClass.android.isDesktopLike, isFalse);
    });
  });

  group('PlatformContext', () {
    test('compoundKey joins platform and device keys', () {
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(ctx.platformKey, 'macos');
      expect(ctx.deviceKey, 'desktop');
      expect(ctx.compoundKey, 'macos_desktop');
    });

    test('equality and hashCode', () {
      final a = PlatformContext(
        platformClass: PlatformClass.ios,
        deviceClass: DeviceClass.phone,
      );
      final b = PlatformContext(
        platformClass: PlatformClass.ios,
        deviceClass: DeviceClass.phone,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when device differs', () {
      final a = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      final b = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.tablet,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('PlatformLayoutResolver', () {
    late PlatformLayoutResolver<String> resolver;

    setUp(() {
      resolver = const PlatformLayoutResolver<String>();
    });

    test('resolves compound key first', () {
      final layouts = <String, String>{
        'macos_desktop': 'macos_desktop_layout',
        'macos': 'macos_layout',
        'desktop': 'desktop_layout',
        'default': 'default_layout',
      };
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(resolver.resolve(layouts, ctx), 'macos_desktop_layout');
    });

    test('falls back to platform key', () {
      final layouts = <String, String>{
        'macos': 'macos_layout',
        'desktop': 'desktop_layout',
        'default': 'default_layout',
      };
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(resolver.resolve(layouts, ctx), 'macos_layout');
    });

    test('falls back to device key', () {
      final layouts = <String, String>{
        'desktop': 'desktop_layout',
        'default': 'default_layout',
      };
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(resolver.resolve(layouts, ctx), 'desktop_layout');
    });

    test('falls back to generic/default key', () {
      final layouts = <String, String>{'default': 'default_layout'};
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(resolver.resolve(layouts, ctx), 'default_layout');
    });

    test('returns null when no layout matches', () {
      final layouts = <String, String>{'mobile': 'mobile_layout'};
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(resolver.resolve(layouts, ctx), isNull);
    });

    test(
      'macOS fallback chain: macos_desktop -> macos -> desktop -> default',
      () {
        final ctx = PlatformContext(
          platformClass: PlatformClass.macos,
          deviceClass: DeviceClass.desktop,
        );
        final keys = resolver.candidateKeys(ctx);
        expect(keys, equals(['macos_desktop', 'macos', 'desktop', 'default']));
      },
    );

    test(
      'iOS phone fallback chain: ios_mobile -> ios -> mobile -> default',
      () {
        final ctx = PlatformContext(
          platformClass: PlatformClass.ios,
          deviceClass: DeviceClass.phone,
        );
        final keys = resolver.candidateKeys(ctx);
        expect(keys, equals(['ios_mobile', 'ios', 'mobile', 'default']));
      },
    );

    test('android tablet fallback chain', () {
      final ctx = PlatformContext(
        platformClass: PlatformClass.android,
        deviceClass: DeviceClass.tablet,
      );
      final keys = resolver.candidateKeys(ctx);
      expect(keys, equals(['android_tablet', 'android', 'tablet', 'default']));
    });

    test('deduplicates identical keys', () {
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      // macos and desktop both have desktop-like, but keys are different strings
      final keys = resolver.candidateKeys(ctx);
      // Keys should be unique
      expect(keys.toSet().length, keys.length);
    });

    test('supports extra fallback keys', () {
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      final keys = resolver.candidateKeys(
        ctx,
        extraFallbackKeys: ['custom_key'],
      );
      expect(keys, contains('custom_key'));
      // extra key appears before 'default'
      final customIndex = keys.indexOf('custom_key');
      final defaultIndex = keys.indexOf('default');
      expect(customIndex, lessThan(defaultIndex));
    });

    test('static resolveLayout works identically', () {
      final layouts = <String, String>{
        'macos': 'macos_layout',
        'default': 'default_layout',
      };
      final ctx = PlatformContext(
        platformClass: PlatformClass.macos,
        deviceClass: DeviceClass.desktop,
      );
      expect(
        PlatformLayoutResolver.resolveLayout(layouts, ctx),
        'macos_layout',
      );
    });

    test('custom genericKey', () {
      final resolver = PlatformLayoutResolver<String>(genericKey: 'fallback');
      final layouts = <String, String>{'fallback': 'fallback_layout'};
      final ctx = PlatformContext(
        platformClass: PlatformClass.ios,
        deviceClass: DeviceClass.phone,
      );
      expect(resolver.resolve(layouts, ctx), 'fallback_layout');
    });
  });
}
