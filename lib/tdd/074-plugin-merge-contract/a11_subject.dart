// IMPLEMENTED (074 phase 2, issue #962): AC-11 — a feature-suite
// failure rolls the host back and the failure names the red behavior.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

import 'merge_fixture.dart';

void subject_a11() {
  final host = snapshotSandbox();
  final baseline = captureBaseline(host);

  // The feature's suite went red in-host: the new red is named.
  final check = ConformanceGate.featureSuite(
    baselineFailures: const [],
    currentFailures: const [
      'login_test: renders the login form after merge [E]',
    ],
  );
  expect(check.pass, isFalse);
  expect(check.offenders.single, contains('renders the login form'));
  expect(check.offenders.single, contains('--> fix:'));

  // The rollback restores the pre-merge host bytes.
  baseline.restore(host.path);
  expect(
    baseline.matchesHost(host.path),
    isTrue,
    reason: 'rollback is byte-identical',
  );
}
