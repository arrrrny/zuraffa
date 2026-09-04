// IMPLEMENTED (073 phase 2, issue #961): AC-14 — merge refuses naming
// the failed check: merge requires a verified slice, and the refusal
// carries the failing check name, its offenders, and the fix hint.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/verify_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_verdict.dart';

import 'sandbox_fixture.dart';

void subject_a14() {
  final host = writeHostProject();
  final sandboxPath = p.join(host.path, '.zuraffa', 'slices', fixtureFeature);
  Directory(sandboxPath).createSync(recursive: true);

  // Suite state failed: merge is refused naming that exact check.
  final failing = SliceVerdict(
    selfContainment: const SliceCheck(name: 'selfContainment', pass: true),
    mockCertification: const SliceCheck(name: 'mockCertification', pass: true),
    suiteState: const SliceCheck(
      name: 'suiteState',
      pass: false,
      offenders: <String>['sandbox suite red: 1 failure [E]'],
    ),
  );
  File(
    VerifySliceCapability.verdictPathFor(sandboxPath),
  ).writeAsStringSync(failing.encode());

  final refusal = MergeSliceCapability.gateOnVerdict(
    sandboxPath,
    sliceName: fixtureFeature,
  );
  expect(refusal, isNotNull, reason: 'merge requires a verified slice');
  expect(refusal!.message, contains('merge requires a verified slice'));
  expect(refusal.message, contains('suiteState'));
  expect(refusal.message, contains('sandbox suite red: 1 failure [E]'));
  expect(refusal.message, contains('--> fix:'));
}
