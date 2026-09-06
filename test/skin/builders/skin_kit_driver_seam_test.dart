// Issue #1112 — the emitted kit's VM-service driver seam: the typed
// element-walk debugTapAnchor (the pilot-proved pattern), the JSON
// evaluate facade the CLI drives, and the widget-test bridge the
// test lane uses (the package:zuraffa_test surface for the target).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/builders/skin_contract_kit_builder.dart';

void main() {
  const builder = SkinContractKitBuilder();

  group('issue #1112 — debugTapAnchor: typed element-walk seam', () {
    late String kit;

    setUp(() => kit = builder.build(routes: const ['login']));

    test('debugTapAnchor returns Future<TapResult> (the issue signature)', () {
      expect(kit, contains('Future<TapResult> debugTapAnchor(String zfaKey)'));
    });

    test('uses the pilot-proved element-walk (renderViewElement walk)', () {
      // rootElement: the post-3.9 replacement for renderViewElement.
      expect(kit, contains('WidgetsBinding.instance.rootElement'));
      expect(kit, contains('visitChildElements(search)'));
    });

    test('finds the anchor BY KEY (ValueKey zfa:<id>)', () {
      expect(kit, contains("ValueKey('zfa:"));
    });

    test('distinguishes disabled from found (contractEnabled / onPressed)', () {
      // The disabled anchor stays discoverable in the tree but refuses
      // the tap — a distinct verdict the driver can report honestly.
      expect(kit, contains('TapDisabled('));
      expect(kit, contains('TapFound('));
    });

    test('an unknown key is notFound (never a silent no-op)', () {
      expect(kit, contains('TapNotFound('));
    });

    test('walk failures surface as error(String), never thrown', () {
      expect(kit, contains('TapError('));
    });

    test('the seam stays kDebugMode-only (release refuses)', () {
      expect(kit, contains('if (!kDebugMode)'));
    });
  });

  group('issue #1112 — debugTapAnchorJson: the evaluate facade', () {
    late String kit;

    setUp(() => kit = builder.build(routes: const []));

    test('exposes a synchronous JSON entry point for vm_service.evaluate', () {
      expect(kit, contains('String debugTapAnchorJson(String zfaKey)'));
      expect(kit, contains('toJsonString()'));
    });

    test('the kit imports dart:convert (JSON on the wire)', () {
      expect(kit, contains("import 'dart:convert'"));
    });

    test('the emitted kit still carries the registry diagnostics', () {
      // The element walk is the driver; the registry remains the
      // registered-anchor diagnostics surface (issue #1102).
      expect(kit, contains('zfaAnchorRegistry'));
      expect(kit, contains('.registered'));
    });
  });

  group('issue #1112 — the widget test bridge (zuraffa_test surface)', () {
    late String bridge;

    setUp(
      () => bridge = builder.buildBridge(
        kitImportPath: '../../lib/src/skin/skin_contract_auditor.dart',
      ),
    );

    test('emits zfaAnchorTapped(tester, zfaKey)', () {
      expect(bridge, contains('Future<TapResult> zfaAnchorTapped('));
      expect(bridge, contains('WidgetTester tester'));
      expect(bridge, contains('String zfaKey'));
    });

    test('the bridge drives the SAME debugTapAnchor element walk', () {
      expect(bridge, contains('debugTapAnchor(zfaKey)'));
    });

    test('pumpAndSettle after a found tap (test-tree anchor is quiet)', () {
      expect(bridge, contains('pumpAndSettle'));
    });

    test('the bridge imports flutter_test + the pure core + the kit', () {
      expect(
        bridge,
        contains("import 'package:flutter_test/flutter_test.dart'"),
      );
      expect(bridge, contains("import 'package:zuraffa/skin.dart'"));
      // The kit import is INJECTED (bridgeKitImport): the app's
      // package: URI when a pubspec name is available. A relative
      // import would compile a SECOND kit library (two registries,
      // dead walk — found the hard way in the scratch-app proof).
      expect(
        bridge,
        contains("import '../../lib/src/skin/skin_contract_auditor.dart'"),
      );
    });

    test('bridgeKitImport falls back honestly without a pubspec', () {
      // A target WITHOUT a readable pubspec gets the relative import
      // (never a crash, never a fabricated package name).
      final import = SkinContractKitBuilder.bridgeKitImport(
        projectRoot: '/tmp/no-such-root-1112',
        kitPath:
            '/tmp/no-such-root-1112/lib/src/skin/skin_contract_auditor.dart',
      );
      expect(import, isNotEmpty);
      expect(import, isNot(contains('package:')));
    });

    test('bridge file name + GENERATED markers (regeneration contract)', () {
      expect(
        SkinContractKitBuilder.bridgeFileName,
        'zfa_anchor_test_bridge.dart',
      );
      expect(bridge, contains('GENERATED - DO NOT EDIT'));
    });
  });
}
