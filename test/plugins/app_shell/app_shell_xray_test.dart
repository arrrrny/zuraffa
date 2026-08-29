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
      expect(src, isNot(contains('xray_bridge_server.dart')));
    });

    test('emits platform-safe bridge imports when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      // Should use conditional import for platform safety
      expect(src, contains("if (dart.library.io)"));
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
      expect(src, contains('await _startXRayBridge();'));
      expect(src, contains('registerAllXRayDecks();'));
    });

    test('emits the bridge start AFTER setupDependencies', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      final setupIdx = src.indexOf('setupDependencies(');
      final bridgeIdx = src.indexOf('await _startXRayBridge();');
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

    test('emits platform-safe _startXRayBridge helper when xray is true', () {
      final src = builder.buildMain(appName: 'my_app', xray: true);
      expect(src, contains('Future<void> _startXRayBridge()'));
      expect(src, contains('Platform-safe X-Ray bridge launcher'));
    });
  });

  group('AppShellBuilder.buildMyApp — xray wiring', () {
    test('does NOT wrap in XRayScope when xray is false (default)', () {
      final src = builder.buildMyApp();
      expect(src, isNot(contains('XRayScope')));
      expect(src, isNot(contains('zuraffa_flutter')));
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

  // ── Spec 036 — Track 4.2 additions ───────────────────────────────────
  // The X-Ray Visual Overlay (issue #181) requires `buildMain(xray: true)`
  // to emit `XRayOverlayState.instance.activate()` inside the existing
  // `if (kDebugMode) { ... }` block so the overlay boots at app start in
  // debug/profile mode, and is tree-shaken in release builds (SC-004).
  group('AppShellBuilder.buildMain — X-Ray Visual Overlay (036)', () {
    test(
      'emits XRayOverlayState.activate() inside kDebugMode when xray true',
      () {
        final src = builder.buildMain(appName: 'demo_app', xray: true);
        expect(src, contains('XRayOverlayState'));
        // Find the LAST `if (kDebugMode)` — earlier matches are in spec
        // comments that mention kDebugMode.
        final debugIdx = src.lastIndexOf('if (kDebugMode)');
        final activateIdx = src.indexOf('XRayOverlayState.instance.activate()');
        expect(debugIdx, greaterThanOrEqualTo(0));
        expect(
          activateIdx,
          greaterThan(debugIdx),
          reason:
              'activate() MUST appear after the kDebugMode guard so '
              'tree-shaking strips it in release builds (SC-004 / FR-007)',
        );
      },
    );

    test('emits XRayOverlayState import when xray true', () {
      final src = builder.buildMain(appName: 'demo_app', xray: true);
      expect(
        src,
        contains('package:zuraffa/src/plugins/xray/xray_overlay.dart'),
      );
    });

    test('does NOT emit XRayOverlayState when xray false (default)', () {
      final src = builder.buildMain(appName: 'demo_app');
      expect(src, isNot(contains('XRayOverlayState')));
    });

    test('activate() appears AFTER registerAllXRayDecks', () {
      final src = builder.buildMain(appName: 'demo_app', xray: true);
      final decksIdx = src.indexOf('registerAllXRayDecks();');
      final activateIdx = src.indexOf('XRayOverlayState.instance.activate()');
      expect(decksIdx, greaterThanOrEqualTo(0));
      expect(
        activateIdx,
        greaterThan(decksIdx),
        reason:
            'activate() must run AFTER decks are registered so the '
            'overlay has a fully-populated mock registry on first paint',
      );
    });
  });
}
