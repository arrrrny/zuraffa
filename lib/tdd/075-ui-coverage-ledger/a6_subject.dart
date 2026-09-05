library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_a6() {
  final ledger = fixtureLedger();
  final verdict = CoverageGate.evaluate(feature: fixtureFeature, rows: ledger);
  expect(verdict.passed, isFalse);
  expect(verdict.failureLines(), isNotEmpty);
  expect(verdict.failureLines().join(' '), contains('submit form'));
  return null;
}
