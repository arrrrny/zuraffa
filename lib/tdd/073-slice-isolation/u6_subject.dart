// IMPLEMENTED (073 phase 2, issue #961): merge reports the host-suite
// outcome — a green host suite keeps the merge successful and reports
// green; a red host suite fails the merge and the report names the
// failures with a fix hint (FR-006).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';

Object? subject_u6() {
  // Green host suite: success stands, report says green.
  final green = MergeSliceCapability.hostSuiteReport(
    mergeClean: true,
    outcome: const HostSuiteOutcome(passed: true),
  );
  expect(green.success, isTrue);
  expect(green.report, contains('Host suite: green.'));

  // Red host suite: the merge fails and the report names the failures.
  final red = MergeSliceCapability.hostSuiteReport(
    mergeClean: true,
    outcome: const HostSuiteOutcome(
      passed: false,
      failures: <String>['host_login_test [E]', 'host_router_test [E]'],
    ),
  );
  expect(red.success, isFalse, reason: 'a red host suite must fail merge');
  expect(red.report, contains('Host suite: FAILED (2)'));
  expect(red.report, contains('host_login_test [E]'));
  expect(red.report, contains('--> fix:'));

  // Even a clean merge cannot succeed behind a red host suite, and a
  // skipped host suite leaves the merge verdict to the merger alone.
  expect(
    MergeSliceCapability.hostSuiteReport(
      mergeClean: true,
      outcome: const HostSuiteOutcome(passed: false),
    ).success,
    isFalse,
  );
  expect(
    MergeSliceCapability.hostSuiteReport(mergeClean: true, outcome: null),
    (r) => r.success && r.report.isEmpty,
  );

  // No test/ directory: the host declares no suite at all. The report
  // names the absence — never "green" — and must not fail the merge.
  final none = MergeSliceCapability.hostSuiteReport(
    mergeClean: true,
    outcome: const HostSuiteOutcome.noSuite(),
  );
  expect(none.success, isTrue, reason: 'a suite-less host must not gate merge');
  expect(none.report, contains('Host suite: none declared.'));
  expect(none.report, isNot(contains('green')));
  // The named outcome stays distinguishable from a run-and-passed suite.
  expect(
    MergeSliceCapability.hostSuiteReport(
      mergeClean: true,
      outcome: const HostSuiteOutcome(passed: true),
    ).report,
    isNot(contains('none declared')),
  );
  return null;
}
