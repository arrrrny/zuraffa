library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';

Object? subject_a1() {
  final ledger = fixtureLedger();
  expect(ledger.length, 3);
  expect(ledger[0].surface, 'Login button text');
  expect(ledger[0].kind, UiSurfaceKind.text);
  expect(ledger[1].surface, '/login');
  expect(ledger[1].kind, UiSurfaceKind.route);
  expect(ledger[2].surface, 'submit form');
  expect(ledger[2].kind, UiSurfaceKind.affordance);
  return null;
}
