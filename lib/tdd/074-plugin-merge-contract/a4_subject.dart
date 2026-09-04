// IMPLEMENTED (074 phase 2, issue #962): AC-4 — the feature's binding
// module registers through the host's locator in both mock and real
// flavors; the generated conformance test constructs the graph per
// flavor and resolves every token.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

import 'merge_fixture.dart';

void subject_a4() {
  final bindings = const [
    DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real'], module: 'login'),
    DiBindingDecl(
      token: 'dependencies/login_repo',
      flavors: ['mock', 'real'],
      module: 'login',
    ),
  ];

  // The generated conformance test registers the feature's binding
  // module and resolves every token per flavor.
  final source = DiGraphCheck.conformanceTestSource(
    feature: 'login',
    bindingModule: 'src/di/login_binding.dart',
    bindings: bindings,
  );
  expect(source, contains("registerLoginBindings();"));
  expect(source, contains("login_binding.dart"));
  expect(source, contains("(flavor: mock)"));
  expect(source, contains("(flavor: real)"));
  expect(source, contains("resolve('dependencies/auth')"));
  expect(source, contains("resolve('dependencies/login_repo')"));

  // Resolution through the host locator: both flavors construct.
  final resolved = DiGraphCheck.resolutionOffenders(
    bindings: bindings,
    resolves: (token, flavor) => true,
  );
  expect(resolved, isEmpty, reason: 'every token resolves per flavor');
}
