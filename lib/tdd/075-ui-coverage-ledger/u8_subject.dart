library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/coverage_gate.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_u8() {
  final v = CoverageGate.evaluate(feature: fixtureFeature, rows: fixtureLedger());
  for (final line in v.failureLines()) {
    expect(line, contains('--> fix:'));
  }
  final missing = XrayLedgerDeck.scenarioEntries(dependency: 'missing', certifiedMockScenarios: {});
  expect(missing.first, contains('--> fix:'));
  return null;
}
