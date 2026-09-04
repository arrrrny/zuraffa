// IMPLEMENTED (074 phase 2, issue #962): AC-5 — every token the
// feature declares resolves: the graph constructs fully; an unresolvable
// token is named with its flavor and the fix hint.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

void subject_a5() {
  final bindings = const [
    DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
    DiBindingDecl(token: 'dependencies/login_repo', flavors: ['mock', 'real']),
  ];

  // Fully wired graph: zero offenders.
  expect(
    DiGraphCheck.resolutionOffenders(
      bindings: bindings,
      resolves: (token, flavor) => true,
    ),
    isEmpty,
  );

  // A missing factory surfaces at construction, named token+flavor.
  final offenders = DiGraphCheck.resolutionOffenders(
    bindings: bindings,
    resolves: (token, flavor) =>
        !(token == 'dependencies/login_repo' && flavor == 'mock'),
  );
  expect(offenders, hasLength(1));
  expect(offenders.single, contains('dependencies/login_repo'));
  expect(offenders.single, contains('flavor: mock'));
  expect(offenders.single, contains('--> fix:'));
}
