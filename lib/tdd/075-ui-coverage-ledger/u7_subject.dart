library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_u7() {
  final entries = XrayLedgerDeck.entries(fixtureLedger());
  expect(entries.length, 3);
  final missing = XrayLedgerDeck.scenarioEntries(
    dependency: 'stripe',
    certifiedMockScenarios: {},
  );
  expect(missing.first, contains('zfa mock dependency stripe'));
  return null;
}
