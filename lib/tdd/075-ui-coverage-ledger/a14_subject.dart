library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_a14() {
  final scenarios = XrayLedgerDeck.scenarioEntries(
    dependency: 'payment_gateway',
    certifiedMockScenarios: {},
  );
  expect(scenarios.length, 1);
  expect(scenarios.first, contains('zfa mock dependency payment_gateway'));
  expect(scenarios.first, contains('--> fix:'));
  return null;
}
