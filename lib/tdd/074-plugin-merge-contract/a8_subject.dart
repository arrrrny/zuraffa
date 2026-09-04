// IMPLEMENTED (074 phase 2, issue #962): AC-8 — an off-convention
// artifact refuses, naming the offending file and the convention.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

import 'merge_fixture.dart';

void subject_a8() {
  final check = ConformanceGate.views(
    viewSources: const {
      'lib/src/presentation/pages/login/login_page.dart': offConventionView,
    },
    shellConvention: 'AdaptiveShell',
  );
  expect(check.pass, isFalse, reason: 'a raw Scaffold bypasses the shell');
  expect(check.offenders, hasLength(1));
  expect(
    check.offenders.single,
    contains('lib/src/presentation/pages/login/login_page.dart'),
    reason: 'the off-convention artifact is named',
  );
  expect(check.offenders.single, contains('AdaptiveShell'));
  expect(check.offenders.single, contains('--> fix:'));
}
