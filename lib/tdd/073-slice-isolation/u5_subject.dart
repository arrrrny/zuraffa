// IMPLEMENTED (073 phase 2, issue #961): the merge gate — merge
// refuses when the verify verdict is absent or failing, naming the
// failed check, and proceeds only behind a passing verdict (FR-005).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/verify_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_verdict.dart';

import 'sandbox_fixture.dart';

Object? subject_u5() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  Directory(sandboxPath).createSync(recursive: true);
  final verdictPath = VerifySliceCapability.verdictPathFor(sandboxPath);

  // Absent verdict: refuse, naming the missing verdict + the fix.
  final absent = MergeSliceCapability.gateOnVerdict(
    sandboxPath,
    sliceName: fixtureFeature,
  );
  expect(absent, isNotNull, reason: 'merge must refuse without a verdict');
  expect(absent!.message, contains('no verify verdict'));
  expect(absent.message, contains('--> fix:'));

  // Failing verdict: refuse, naming the failed check.
  final failing = SliceVerdict(
    selfContainment: const SliceCheck(name: 'selfContainment', pass: true),
    mockCertification: const SliceCheck(
      name: 'mockCertification',
      pass: false,
      offenders: ['GoRouterHost -- unbound'],
    ),
    suiteState: const SliceCheck(name: 'suiteState', pass: true),
  );
  File(verdictPath).writeAsStringSync(failing.encode());
  final refused = MergeSliceCapability.gateOnVerdict(
    sandboxPath,
    sliceName: fixtureFeature,
  );
  expect(refused, isNotNull, reason: 'merge must refuse a failing verdict');
  expect(refused!.message, contains('merge requires a verified slice'));
  expect(refused.message, contains('mockCertification'));
  expect(refused.message, contains('GoRouterHost'));

  // Passing verdict: the gate opens (null refusal).
  final passing = SliceVerdict(
    selfContainment: const SliceCheck(name: 'selfContainment', pass: true),
    mockCertification: const SliceCheck(name: 'mockCertification', pass: true),
    suiteState: const SliceCheck(name: 'suiteState', pass: true),
  );
  File(verdictPath).writeAsStringSync(passing.encode());
  expect(
    MergeSliceCapability.gateOnVerdict(sandboxPath, sliceName: fixtureFeature),
    isNull,
  );
  return null;
}
