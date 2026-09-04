library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_a13() {
  final scenarios = XrayLedgerDeck.scenarioEntries(
    dependency: 'firebase_auth',
    certifiedMockScenarios: {
      'firebase_auth': ['sign-in anonymous', 'sign-in email'],
    },
  );
  expect(scenarios.length, 2);
  expect(scenarios.first, 'sign-in anonymous');
  return null;
}
