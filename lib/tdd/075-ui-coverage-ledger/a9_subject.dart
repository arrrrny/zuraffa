library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_a9() {
  final ledger = fixtureLedger();
  expect(XrayLedgerOverlay.paint(surface: 'Login button text', ledger: ledger), XrayLedgerPaint.clean);
  expect(XrayLedgerOverlay.paint(surface: 'submit form', ledger: ledger), XrayLedgerPaint.highlight);
  final highlights = XrayLedgerOverlay.highlights(ledger);
  expect(highlights, contains('submit form'));
  expect(highlights, isNot(contains('Login button text')));
  return null;
}
