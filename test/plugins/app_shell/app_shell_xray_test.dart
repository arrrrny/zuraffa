import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

/// Tests for the X-Ray wiring added in issue #360.
///
/// When `xray: true` is passed to `buildMain` / `buildMyApp`:
/// - `buildMain` emits the bridge server start + `registerAllXRayDecks()`
///   call inside `if (kDebugMode) { ... }`.
/// - `buildMyApp` wraps `MaterialApp.router` in `XRayScope(viewId: 'App')`.
/// - `buildXRayDecksBarrel` emits a barrel that exports
///   `registerAllXRayDecks()`.
void main() {
  const builder = AppShellBuilder();

  group('AppShellBuilder.buildMain — xray wiring', () {
    test('does NOT emit X-Ray imports when xray is false (default)', () {
      final src = builder.buildMain(appName: 'my_app');
      expect(src, isNot(contains('XRayBridgeServer')));
      expect(src, isNot(contains('registerAllXRayDecks')));
      expect(src, isNot(contains('kDebugMode')));
      expect(
        src,
        isNot(contains('xray_bridge_server.dart')),
      );
    });

    test('emits XRayBridgeServer import when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(
        src,
        contains(
          "import 'package:zuraffa_flutter/src/presentation/xray/xray_bridge_server.dart';",
        ),
      );
    });

    test('emits foundation import for kDebugMode when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(src, contains("import 'package:flutter/foundation.dart';"));
    });

    test('emits xray_decks barrel import when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(
        src,
        contains("import 'package:my_app/src/xray/xray_decks.dart';"),
      );
    });

    test('emits kDebugMode guard with bridge start when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(src, contains('if (kDebugMode)'));
      expect(src, contains('await XRayBridgeServer().start();'));
      expect(src, contains('registerAllXRayDecks();'));
    });

    test('emits the bridge start AFTER setupDependencies', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      final setupIdx = src.indexOf('await setupDependencies()');
      final bridgeIdx = src.indexOf('XRayBridgeServer');
      expect(setupIdx, greaterThanOrEqualTo(0));
      expect(bridgeIdx, greaterThan(setupIdx));
    });

    test('derives xray_decks import from a custom output dir', () {
      final src = builder.buildMain(
        appName: 'my_app',
        outputDir: 'lib/custom',
        xray: true,
      );
      expect(
        src,
        contains("import 'package:my_app/custom/xray/xray_decks.dart';"),
      );
    });

    test('stamps the file with the X-Ray wiring header when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(src, contains('X-Ray wiring (issue #360)'));
    });
  });

  group('AppShellBuilder.buildMyApp — xray wiring', () {
    test('does NOT wrap in XRayScope when xray is false (default)', () {
      final src = builder.buildMyApp();
      expect(src, isNot(contains('XRayScope')));
      expect(
        src,
        isNot(contains('zuraffa_flutter')),
      );
    });

    test('imports zuraffa_flutter when xray is true', () {
      final src = builder.buildMyApp(xray: true);
      expect(
        src,
        contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
      );
    });

    test('wraps MaterialApp.router in XRayScope when xray is true', () {
      final src = builder.buildMyApp(xray: true);
      expect(src, contains('XRayScope('));
      expect(src, contains("viewId: 'App'"));
      expect(src, contains('MaterialApp.router('));
    });

    test('XRayScope wraps MaterialApp.router (not the other way around)', () {
      final src = builder.buildMyApp(xray: true);
      final scopeIdx = src.indexOf('XRayScope(');
      final materialIdx = src.indexOf('MaterialApp.router(');
      expect(scopeIdx, greaterThanOrEqualTo(0));
      expect(materialIdx, greaterThan(scopeIdx));
    });
  });

  group('AppShellBuilder.buildXRayDecksBarrel', () {
    test('emits a registerAllXRayDecks function', () {
      final src = builder.buildXRayDecksBarrel();
      expect(src, contains('void registerAllXRayDecks()'));
    });

    test('emits a kReleaseMode guard', () {
      final src = builder.buildXRayDecksBarrel();
      expect(src, contains('if (kReleaseMode) return;'));
    });

    test('imports flutter foundation', () {
      final src = builder.buildXRayDecksBarrel();
      expect(src, contains("import 'package:flutter/foundation.dart';"));
    });

    test('emits a comment hint when no registrations are passed', () {
      final src = builder.buildXRayDecksBarrel();
      expect(src, contains('zfa xray deck'));
    });

    test('includes registration calls when provided', () {
      final src = builder.buildXRayDecksBarrel(
        deckImports: ['user_xray_deck.dart'],
        registrationCalls: ['registerUserXRayDeck();'],
      );
      expect(src, contains("import 'user_xray_deck.dart';"));
      expect(src, contains('registerUserXRayDeck();'));
    });

    test('stamps the file with the zfa header', () {
      final src = builder.buildXRayDecksBarrel();
      expect(src.startsWith('// Generated by zfa'), isTrue);
    });
  });
}
