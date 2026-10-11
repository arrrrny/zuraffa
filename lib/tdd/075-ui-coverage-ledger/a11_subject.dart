library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_a11() {
  final ledger = fixtureLedger();
  final entries = XrayLedgerDeck.entries(ledger);
  expect(entries.length, 3);
  expect(entries[0].label, contains('Login button text'));
  expect(entries[0].state, 'DONE');
  expect(entries[2].state, 'NOT-DONE');
  return null;
}
