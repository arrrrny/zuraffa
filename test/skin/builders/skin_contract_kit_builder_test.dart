// Issue #1102 — SkinContractKitBuilder: emits the Flutter glue of the
// runtime skin-contract auditor into target projects (the framework
// itself stays pure-Dart, Constitution VII).
library;

import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/skin/builders/skin_contract_kit_builder.dart';

void main() {
  group('issue #1102 — SkinContractKitBuilder.build', () {
    final builder = const SkinContractKitBuilder();

    test('emits the kit file header identifying the spec', () {
      final src = builder.build();
      expect(src, contains('1102'));
      expect(src, contains('runtime skin-contract auditor'));
    });

    test('emits inspectTree(Element) -> TreeFacts', () {
      final src = builder.build();
      expect(src, contains('TreeFacts inspectTree(Element root)'));
    });

    test('inspectTree collects texts, zfa: anchors, progress, platform', () {
      final src = builder.build();
      // Texts: Text/RichText data collection.
      expect(src, contains('Text'));
      // zfa: anchors via ValueKey/Key strings.
      expect(src, contains("startsWith('zfa:')"));
      // Progress indicators (the loading-scrim contract, lesson 1).
      expect(src, contains('CircularProgressIndicator'));
      expect(src, contains('LinearProgressIndicator'));
      // Platform from Theme (the override-aware source, lesson 8).
      expect(src, contains('Theme.of'));
      expect(src, contains('TargetPlatform.'));
    });

    test('emits the SkinContractAuditor widget (subscribe-don-t-poll)', () {
      final src = builder.build();
      expect(src, contains('class SkinContractAuditor'));
      expect(src, contains('final List<SkinContractRow> rows'));
      // Subscribe-don't-poll: the audit is scheduled ONLY when the
      // scheduler consumed a dirty mark (lesson 5).
      expect(src, contains('consumeDirty()'));
      expect(src, contains('markDirty('));
    });

    test('emits the SkinRouteContractObserver (NavigatorObserver)', () {
      final src = builder.build();
      expect(src, contains('class SkinRouteContractObserver'));
      expect(src, contains('extends NavigatorObserver'));
      expect(src, contains('RouteContractTable table'));
      // The observer validates on push/replace.
      expect(src, contains('didPush'));
    });

    test('emits the debug chrome: bus, banner, chrome widget', () {
      final src = builder.build();
      expect(src, contains('class SkinAuditBus'));
      expect(src, contains('class SkinAuditChrome'));
      expect(src, contains('class SkinViolationBanner'));
      // The banner is impossible to miss: deep red, full-width, top.
      expect(src, contains('Colors.red'));
    });

    test(
      'emits the typed anchor button (contractId/contractEnabled, #1099)',
      () {
        final src = builder.build();
        expect(src, contains('class ZfaButton'));
        expect(src, contains('final String contractId'));
        expect(src, contains('final bool contractEnabled'));
        // The typed anchor carries the zfa: ValueKey.
        expect(src, contains("ValueKey('zfa:\$contractId')"));
      },
    );

    test('emits the debugTapAnchor VM-service driver seam (lesson 7)', () {
      final src = builder.build();
      expect(src, contains('Future<bool> debugTapAnchor(String zfaKey)'));
      expect(src, contains('zfaAnchorRegistry'));
    });

    test('everything is debug-only: kDebugMode guards (zero release cost)', () {
      final src = builder.build();
      expect(src, contains('kDebugMode'));
    });

    test('imports the pure kit core from package:zuraffa/skin.dart', () {
      final src = builder.build();
      expect(src, contains("import 'package:zuraffa/skin.dart'"));
    });

    test('emits the route contract table from the given routes', () {
      final src = builder.build(routes: const ['deal_list', 'login']);
      expect(src, contains('kSkinRouteContract'));
      expect(src, contains("'deal_list'"));
      expect(src, contains("'login'"));
    });

    test('the route table always allows the navigator root (lesson 3)', () {
      final src = builder.build(routes: const []);
      expect(src, contains("navigatorRootRoute"));
    });

    test('the emitted source is syntactically valid Dart (formats clean)', () {
      final src = builder.build(routes: const ['deal_list']);
      // DartFormatter throws on syntactically invalid input — a clean
      // format pass is the compile-adjacent syntax proof for emitted
      // Flutter glue in a pure-Dart framework repo.
      final formatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(src);
      expect(formatted, isNotEmpty);
    });

    test('emission is deterministic (same input, same bytes)', () {
      final a = builder.build(routes: const ['deal_list']);
      final b = builder.build(routes: const ['deal_list']);
      expect(a, equals(b));
    });

    test(' GENERATED markers wrap the kit (smart regeneration)', () {
      final src = builder.build();
      expect(src, contains('// GENERATED - DO NOT EDIT'));
      expect(src, contains('// END GENERATED'));
    });
  });
}
