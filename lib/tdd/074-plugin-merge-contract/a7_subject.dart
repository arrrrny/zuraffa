// IMPLEMENTED (074 phase 2, issue #962): AC-7 — each merged page
// composes behind the host's adaptive shell convention; conforming
// views pass the structural check.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

import 'merge_fixture.dart';

void subject_a7() {
  final check = ConformanceGate.views(
    viewSources: const {
      'lib/src/presentation/pages/login/login_page.dart': conformingView,
      'lib/src/presentation/pages/login/register_page.dart':
          'class RegisterPage extends StatelessWidget {\n'
          '  @override\n'
          '  Widget build(BuildContext context) =>\n'
          '      AdaptiveShell(child: RegisterView());\n'
          '}',
    },
    shellConvention: 'AdaptiveShell',
  );
  expect(check.pass, isTrue, reason: check.offenders.join('\n'));
  // Evidence: the checked views are recorded on a pass.
  expect(check.evidence, hasLength(2));
}
