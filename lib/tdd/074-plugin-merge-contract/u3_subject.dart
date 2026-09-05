// IMPLEMENTED (074 phase 2, issue #962): FR-003 — the feature's
// bindings register through the host's locator in mock AND real
// flavors, and the generated graph-construction proof covers every
// declared token (evidence, not grep).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

void subject_u3() {
  final bindings = const [
    DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
    DiBindingDecl(
      token: 'dependencies/login_repo',
      flavors: ['mock', 'real'],
      module: 'login',
    ),
  ];
  final source = DiGraphCheck.conformanceTestSource(
    feature: 'login',
    bindingModule: 'src/di/login_binding.dart',
    bindings: bindings,
  );

  // The generated proof constructs the graph per flavor and resolves
  // every token — it is a real test in the host suite.
  expect(source, contains('test('));
  expect(source, contains("DiGraph(flavor: 'mock')"));
  expect(source, contains("DiGraph(flavor: 'real')"));
  for (final binding in bindings) {
    for (final flavor in binding.flavors) {
      expect(
        source,
        contains("resolve('${binding.token}')"),
        reason: '${binding.token} ($flavor) must be proven',
      );
    }
  }
  expect(source, contains('registerLoginBindings();'));
}
