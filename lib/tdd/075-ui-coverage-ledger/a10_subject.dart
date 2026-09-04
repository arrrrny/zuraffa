library;
import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';
import 'sandbox_fixture.dart';

Object? subject_a10() {
  var ledger = UiLedgerBuilder.derive(declared: fixtureSurfaces(), greenBehaviors: {'A1'});
  expect(XrayLedgerOverlay.paint(surface: '/login', ledger: ledger), XrayLedgerPaint.highlight);
  ledger = UiLedgerBuilder.derive(declared: fixtureSurfaces(), greenBehaviors: {'A1', 'A2'});
  expect(XrayLedgerOverlay.paint(surface: '/login', ledger: ledger), XrayLedgerPaint.clean);
  return null;
}
