// IMPLEMENTED (074 phase 2, issue #962): FR-007 — the feature-suite
// gate is baseline-aware: pre-existing reds never fail a merge; new
// reds always do.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

void subject_u7() {
  // Pre-existing reds (in the baseline) are tolerated — the gate passes
  // and the evidence records them as prior, not new.
  final tolerated = ConformanceGate.featureSuite(
    baselineFailures: const ['flaky_host_test [E]'],
    currentFailures: const ['flaky_host_test [E]'],
  );
  expect(tolerated.pass, isTrue, reason: 'pre-existing reds are never blamed');

  // New reds fail the gate, named.
  final newRed = ConformanceGate.featureSuite(
    baselineFailures: const ['flaky_host_test [E]'],
    currentFailures: const [
      'flaky_host_test [E]',
      'login_after_merge_test [E]',
    ],
  );
  expect(newRed.pass, isFalse);
  expect(newRed.offenders, hasLength(1));
  expect(newRed.offenders.single, contains('login_after_merge_test [E]'));

  // A healed prior red is an improvement, not a failure.
  final healed = ConformanceGate.featureSuite(
    baselineFailures: const ['flaky_host_test [E]'],
    currentFailures: const [],
  );
  expect(healed.pass, isTrue);
}
