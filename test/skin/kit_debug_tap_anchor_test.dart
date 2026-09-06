// Issue #1112 — the EMITTED kit's driver seam. The pure registry
// answers verdicts; the emitted Flutter glue (skin_contract_auditor.dart)
// must expose the ISSUE's signature `Future<TapResult>
// debugTapAnchor(String zfaKey)`, walk the LIVE tree the pilot proved
// (renderViewElement + visitChildElements), and speak the same JSON.
//
// This repo's lib/ never imports Flutter (Constitution VII), so the
// emitted glue is pinned structurally here — the established pattern
// (view_skin_audit_wrap_test, skin_contract_kit_builder_test).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/builders/skin_contract_kit_builder.dart';

void main() {
  group('issue #1112 — emitted kit debugTapAnchor (the driver seam)', () {
    final src = const SkinContractKitBuilder().build(routes: const ['login']);

    test('T3.1 declares the issue signature Future<TapResult>', () {
      expect(src, contains('Future<TapResult> debugTapAnchor(String zfaKey)'));
      // The old bool surface is gone.
      expect(src, isNot(contains('Future<bool> debugTapAnchor')));
    });

    test(
      'T3.2 kDebugMode-only: release path refuses with an error verdict',
      () {
        expect(src, contains('if (!kDebugMode)'));
        expect(
          src,
          contains("TapResult.error('debugTapAnchor requires kDebugMode')"),
        );
      },
    );

    test('T3.3 uses the pilot-proven element walk', () {
      expect(src, contains('renderViewElement'));
      expect(src, contains('visitChildElements'));
    });

    test('T3.4 maps the four verdicts honestly', () {
      // Absent key -> notFound.
      expect(src, contains('TapResult.notFound'));
      // Mounted but inert (disabled or null onPressed) -> disabled.
      expect(src, contains('TapResult.disabled'));
      // Enabled -> invoke the REAL onPressed -> found.
      expect(src, contains('TapResult.found'));
      // A throwing handler -> error, never a crash up the driver.
      expect(src, contains('TapResult.error'));
    });

    test(
      'T3.5 debugTapAnchorJson is the sync String the VM evaluate calls',
      () {
        expect(src, contains("String debugTapAnchorJson(String zfaKey)"));
        expect(src, contains('jsonEncode('));
      },
    );

    test('T3.6 ZfaButton registers its LIVE enabled state', () {
      expect(src, contains('zfaAnchorRegistry.register('));
      // The live enabled state flows into the registry (formatter-
      // stable pin: the argument, not one exact call layout).
      expect(src, contains('enabled: widget.contractEnabled'));
    });
  });
}
