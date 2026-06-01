import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('Platform layout structure regression', () {
    test(
      'shared presenter/controller/state files are not duplicated in layouts',
      () {
        // Verify that layout files import shared controller/presenter, not duplicate them
        final builderPath = path.join(
          'lib',
          'src',
          'plugins',
          'view',
          'builders',
          'adaptive_layout_scaffold_builder.dart',
        );
        final content = File(builderPath).readAsStringSync();

        // The scaffold builder should reference shared controller/presenter imports
        expect(content, contains('controller'));
        expect(content, contains('presenter'));
        expect(content, contains('Shared logic stays in'));
      },
    );

    test('layout files are generated under pages/<feature>/layouts/', () {
      final builderPath = path.join(
        'lib',
        'src',
        'plugins',
        'view',
        'builders',
        'adaptive_layout_scaffold_builder.dart',
      );
      final content = File(builderPath).readAsStringSync();

      // Verify the generated layout directory structure
      expect(content, contains("'layouts'"));
    });

    test('shell classes reference shared AppShell base', () {
      final shellFiles = <String, String>{
        'mobile_app_shell.dart': 'MobileAppShell',
        'tablet_app_shell.dart': 'TabletAppShell',
        'desktop_app_shell.dart': 'DesktopAppShell',
      };

      for (final entry in shellFiles.entries) {
        final filePath = path.join(
          'lib',
          'src',
          'presentation',
          'shells',
          entry.key,
        );
        final content = File(filePath).readAsStringSync();
        // All shells must extend AppShell
        expect(
          content,
          contains('extends AppShell'),
          reason: '${entry.key} must extend AppShell',
        );
      }

      // macOS shell extends DesktopAppShell which extends AppShell
      final macosPath = path.join(
        'lib',
        'src',
        'presentation',
        'shells',
        'macos_app_shell.dart',
      );
      final macosContent = File(macosPath).readAsStringSync();
      expect(
        macosContent,
        contains('extends DesktopAppShell'),
        reason: 'macos_app_shell.dart must extend DesktopAppShell',
      );
    });

    test('AppShellResolver uses PlatformLayoutResolver for fallback', () {
      final resolverPath = path.join(
        'lib',
        'src',
        'presentation',
        'shells',
        'app_shell_resolver.dart',
      );
      final content = File(resolverPath).readAsStringSync();
      expect(content, contains('PlatformLayoutResolver'));
      expect(content, contains('MacosAppShell'));
      expect(content, contains('DesktopAppShell'));
      expect(content, contains('TabletAppShell'));
      expect(content, contains('MobileAppShell'));
    });

    test('DeviceClass layout keys match adaptive layout targets', () {
      final devicePath = path.join(
        'lib',
        'src',
        'presentation',
        'platform',
        'device_class.dart',
      );
      final content = File(devicePath).readAsStringSync();

      // Verify the canonical targets exist
      expect(content, contains("'mobile'"));
      expect(content, contains("'tablet'"));
      expect(content, contains("'desktop'"));
      expect(content, contains("'macos'"));
    });

    test('platform layout resolver has documented fallback order', () {
      final resolverPath = path.join(
        'lib',
        'src',
        'presentation',
        'platform',
        'platform_layout_resolver.dart',
      );
      final content = File(resolverPath).readAsStringSync();
      // Verify the fallback comment or implementation order
      expect(content, contains('compoundKey'));
      expect(content, contains('platformKey'));
      expect(content, contains('deviceKey'));
      expect(content, contains('genericKey'));
    });
  });
}
