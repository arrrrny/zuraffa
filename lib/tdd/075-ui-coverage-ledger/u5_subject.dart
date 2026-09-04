library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/coverage_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

Object? subject_u5() {
  final v = CoverageGate.evaluate(feature: fixtureFeature, rows: fixtureLedger());
  final check = CoverageCheck.fromCounts(surfaces: v.surfaces, proven: v.proven, gaps: v.gaps);
  expect(check.pass, isFalse, reason: 'submit form is unproven');
  expect(check.name, 'coverage');
  return null;
}
