// IMPLEMENTED (074 phase 2, issue #962): FR-004 — merged views compose
// behind the host's adaptive shell convention; off-convention artifacts
// are refused naming the file.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

import 'merge_fixture.dart';

void subject_u4() {
  // Conforming and off-convention views, checked together: the
  // off-convention one is named, the conforming one is not.
  final check = ConformanceGate.views(
    viewSources: const {
      'lib/src/presentation/pages/login/login_page.dart': offConventionView,
      'lib/src/presentation/pages/login/register_page.dart': conformingView,
    },
    shellConvention: 'AdaptiveShell',
  );
  expect(check.pass, isFalse);
  expect(check.offenders, hasLength(1));
  expect(check.offenders.single, contains('login_page.dart'));
  expect(check.offenders.single, contains('--> fix:'));
}
