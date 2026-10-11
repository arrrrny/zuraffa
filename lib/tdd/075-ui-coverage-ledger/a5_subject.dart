library;

import 'dart:convert';

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Object? subject_a5() {
  // All green: A1,A2 — A3 is NOT-DONE so gate won't pass.
  // Use all-green to get exit 0.
  final allGreen = UiLedgerBuilder.derive(
    declared: fixtureSurfaces(),
    greenBehaviors: {'A1', 'A2', 'A3'},
  );
  final verdict = CoverageGate.evaluate(
    feature: fixtureFeature,
    rows: allGreen,
  );
  expect(verdict.passed, isTrue);
  final json = jsonDecode(verdict.encode()) as Map;
  expect(json['passed'], isTrue);
  expect(json['surfaces'], isA<List>());
  return null;
}
