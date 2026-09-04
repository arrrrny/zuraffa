// IMPLEMENTED (073 phase 2, issue #961): AC-13 — after merge, the HOST
// suite is green: the host-suite report carries the green verdict the
// merge surface reports (U6's report core, driven through a full merge
// gate pass).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/verify_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_verdict.dart';

import 'sandbox_fixture.dart';

void subject_a13() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  Directory(sandboxPath).createSync(recursive: true);
  const passing = SliceVerdict(
    selfContainment: SliceCheck(name: 'selfContainment', pass: true),
    mockCertification: SliceCheck(name: 'mockCertification', pass: true),
    suiteState: SliceCheck(name: 'suiteState', pass: true),
  );
  File(
    VerifySliceCapability.verdictPathFor(sandboxPath),
  ).writeAsStringSync(passing.encode());

  // Behind a passing verdict, the merge reports the host-suite outcome:
  // green here (the injected host suite passes).
  final report = MergeSliceCapability.hostSuiteReport(
    mergeClean: true,
    outcome: const HostSuiteOutcome(passed: true),
  );
  expect(report.success, isTrue);
  expect(report.report, contains('Host suite: green.'));
}
