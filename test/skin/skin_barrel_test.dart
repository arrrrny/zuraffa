// Issue #1102 — the public kit barrel: generated Flutter apps import
// the pure SkinContractKit core via package:zuraffa/skin.dart.
library;

import 'package:test/test.dart';
import 'package:zuraffa/skin.dart';

void main() {
  group('issue #1102 — package:zuraffa/skin.dart exports the kit core', () {
    test('TreeFacts + SkinTargetPlatform are importable', () {
      final facts = TreeFacts(
        texts: const ['Sign in'],
        anchors: const {'zfa:signin-guest'},
        platform: SkinTargetPlatform.macos,
      );
      expect(facts.texts, isNotEmpty);
    });

    test('SkinContractRow + helpers are importable', () {
      final row = SkinContractRow.textRenders(id: 'x', text: 'Sign in');
      expect(row.id, 'x');
    });

    test('SkinViolation + kinds are importable', () {
      final violation = SkinViolation.widget(
        rowId: 'x',
        requirement: 'r',
        message: 'm',
      );
      expect(violation.kind, SkinViolationKind.widget);
    });

    test('RouteContractTable is importable', () {
      final table = RouteContractTable.fromRouteNames(const {'login'});
      expect(table.validatePush('/'), isNull);
    });

    test('SkinAuditController is importable', () {
      final controller = SkinAuditController();
      expect(controller.hasViolations, isFalse);
    });

    test('SkinAuditScheduler is importable', () {
      final scheduler = SkinAuditScheduler();
      expect(scheduler.isDirty, isFalse);
    });

    test('ZfaAnchors + ZfaAnchorRegistry are importable', () {
      expect(ZfaAnchors.keyFor('guest'), 'zfa:guest');
      final registry = ZfaAnchorRegistry();
      expect(registry.registered, isEmpty);
    });
  });
}
