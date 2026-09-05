library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_u6() {
  expect(
    XrayLedgerOverlay.paint(surface: 'x', ledger: null),
    XrayLedgerPaint.noLedger,
  );
  final ledger = fixtureLedger();
  expect(
    XrayLedgerOverlay.paint(surface: 'Login button text', ledger: ledger),
    XrayLedgerPaint.clean,
  );
  expect(
    XrayLedgerOverlay.paint(surface: 'submit form', ledger: ledger),
    XrayLedgerPaint.highlight,
  );
  return null;
}
