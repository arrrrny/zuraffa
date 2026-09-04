library;

import 'dart:convert';
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/coverage_gate.dart';

Object? subject_u4() {
  final allGreen = UiLedgerBuilder.derive(
    declared: fixtureSurfaces(),
    greenBehaviors: {'A1', 'A2', 'A3'},
  );
  final v = CoverageGate.evaluate(feature: fixtureFeature, rows: allGreen);
  expect(v.passed, isTrue);
  final json = jsonDecode(v.encode()) as Map;
  expect(json['check'], 'ui-coverage');
  expect(json['passed'], true);
  expect(v.failureLines(), isEmpty);
  return null;
}
