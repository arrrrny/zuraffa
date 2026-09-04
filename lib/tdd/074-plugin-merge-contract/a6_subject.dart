// IMPLEMENTED (074 phase 2, issue #962): AC-6 — every dependency
// touchpoint serves the certified mock: in the mock flavor the mock is
// what the locator serves; the conformance evidence records each
// token@flavor resolution.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

void subject_a6() {
  final bindings = const [
    DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
    DiBindingDecl(token: 'dependencies/login_repo', flavors: ['mock', 'real']),
  ];

  // The mock flavor serves the CERTIFIED mock at every touchpoint.
  final mockServings = <String>{};
  final check = ConformanceGate.di(
    bindings: bindings,
    resolves: (token, flavor) {
      if (flavor == 'mock') mockServings.add(token);
      return true;
    },
  );
  expect(check.pass, isTrue);
  expect(
    mockServings,
    containsAll(bindings.map((b) => b.token)),
    reason: 'the mock flavor served every touchpoint',
  );
  // Evidence: each token@flavor pair is recorded.
  expect(check.evidence, contains('dependencies/auth@mock'));
  expect(check.evidence, contains('dependencies/auth@real'));
  expect(check.evidence, hasLength(4));
}
