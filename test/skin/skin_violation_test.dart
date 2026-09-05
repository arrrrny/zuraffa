// Issue #1102 — SkinViolation: what a broken contract surfaces on the
// impossible-to-miss banner.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/skin_violation.dart';

void main() {
  group('issue #1102 — SkinViolation', () {
    test('widget violation renders the pilot display line shape', () {
      final violation = SkinViolation.widget(
        rowId: 'google-text',
        requirement: 'Continue with Google renders',
        message: 'text "Continue with Google" not found in the live tree',
      );
      expect(violation.kind, SkinViolationKind.widget);
      expect(
        violation.toDisplayLine(),
        '[google-text] Continue with Google renders',
      );
    });

    test('route violation carries the pushed route', () {
      final violation = SkinViolation.route(
        rowId: 'route:debug-thing',
        requirement: 'route debug-thing is declared by the route contract',
        message: 'push of undeclared route',
        route: 'debug-thing',
      );
      expect(violation.kind, SkinViolationKind.route);
      expect(violation.route, 'debug-thing');
      expect(violation.toDisplayLine(), startsWith('[route:debug-thing]'));
      expect(violation.toDisplayLine(), contains('debug-thing'));
    });

    test('kind labels are stable machine names', () {
      expect(SkinViolationKind.widget.label, 'widget');
      expect(SkinViolationKind.route.label, 'route');
    });

    test(
      'equality ignores the timestamp (identity is the contract breach)',
      () {
        final a = SkinViolation.widget(
          rowId: 'google-text',
          requirement: 'r',
          message: 'm',
        );
        final b = SkinViolation.widget(
          rowId: 'google-text',
          requirement: 'r',
          message: 'm',
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      },
    );

    test('different row ids are different violations', () {
      final a = SkinViolation.widget(
        rowId: 'a',
        requirement: 'r',
        message: 'm',
      );
      final b = SkinViolation.widget(
        rowId: 'b',
        requirement: 'r',
        message: 'm',
      );
      expect(a, isNot(equals(b)));
    });

    test('toJson is machine-readable (kind, rowId, requirement, message)', () {
      final json = SkinViolation.route(
        rowId: 'route:x',
        requirement: 'route x is declared',
        message: 'undeclared push',
        route: 'x',
      ).toJson();
      expect(json['kind'], 'route');
      expect(json['rowId'], 'route:x');
      expect(json['requirement'], 'route x is declared');
      expect(json['message'], 'undeclared push');
      expect(json['route'], 'x');
    });
  });
}
