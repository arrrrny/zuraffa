library;
import 'package:test/test.dart';
import 'sandbox_fixture.dart';
import 'package:zuraffa/src/tdd/services/coverage_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

Object? subject_a7() {
  final ledger = fixtureLedger();
  final verdict = CoverageGate.evaluate(feature: fixtureFeature, rows: ledger);
  final check = CoverageCheck.fromCounts(
    surfaces: verdict.surfaces,
    proven: verdict.proven,
    gaps: verdict.gaps,
  );
  expect(check.pass, isFalse);
  expect(check.offenders.join(' '), contains('submit form'));
  return null;
}
