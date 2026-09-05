library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_a2() {
  final ledger = fixtureLedger();
  final loginBtn = ledger.firstWhere((r) => r.surface == 'Login button text');
  expect(loginBtn.state, 'DONE');
  expect(loginBtn.provers, contains('A1'));
  final route = ledger.firstWhere((r) => r.surface == '/login');
  expect(route.state, 'DONE');
  expect(route.provers, contains('A2'));
  return null;
}
