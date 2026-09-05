// IMPLEMENTED (074 phase 2, issue #962): FR-009 — every refusal and
// failed gate names the offending artifact, token, or behavior with a
// `--> fix:` hint, across all four gates and the route conflict refusal.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

import 'merge_fixture.dart';

void subject_u9() {
  // Route conflict refusal: names both registrations + the fix.
  final conflict = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: const [
      RouteDecl(path: '/settings', page: 'LoginPage', module: 'login'),
    ],
  );
  expect(conflict.passed, isFalse);
  final conflicts = conflict.conflicts.join(' ');
  expect(conflicts, contains('/settings'));
  expect(conflicts, contains('SettingsPage'));
  expect(conflicts, contains('--> fix:'));

  // Routes gate: unresolved route named.
  final routes = ConformanceGate.routes(
    barrel: hostBarrel,
    declared: featureRoutes,
  );
  expect(routes.offenders.join(' '), contains('--> fix:'));

  // DI gate: token + flavor named.
  final di = ConformanceGate.di(
    bindings: const [
      DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
    ],
    resolves: (token, flavor) => flavor != 'real',
  );
  expect(di.offenders.single, contains("dependencies/auth' (flavor: real)"));
  expect(di.offenders.single, contains('--> fix:'));

  // Views + feature-suite gates: artifact / behavior named.
  final views = ConformanceGate.views(
    viewSources: const {'lib/src/pages/login_page.dart': offConventionView},
    shellConvention: 'AdaptiveShell',
  );
  expect(views.offenders.single, contains('lib/src/pages/login_page.dart'));
  expect(views.offenders.single, contains('--> fix:'));
  final suite = ConformanceGate.featureSuite(
    baselineFailures: const [],
    currentFailures: const ['new_login_test [E]'],
  );
  expect(suite.offenders.single, contains('new_login_test [E]'));
  expect(suite.offenders.single, contains('--> fix:'));
}
