// IMPLEMENTED (074 phase 2, issue #962): FR-005 — merge runs the
// conformance suite after landing and produces the machine-readable
// verdict; the summary line is the final stdout contract.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

import 'merge_fixture.dart';

void subject_u5() {
  final barrel = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  ).barrel;

  final verdict = MergeVerdict(
    feature: 'login',
    routes: ConformanceGate.routes(barrel: barrel, declared: featureRoutes),
    di: ConformanceGate.di(
      bindings: const [
        DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
        DiBindingDecl(
          token: 'dependencies/login_repo',
          flavors: ['mock', 'real'],
        ),
      ],
      resolves: (token, flavor) => true,
    ),
    views: ConformanceGate.views(
      viewSources: const {
        'lib/src/presentation/pages/login/login_page.dart': conformingView,
      },
      shellConvention: 'AdaptiveShell',
    ),
    featureSuite: ConformanceGate.featureSuite(
      baselineFailures: const [],
      currentFailures: const [],
    ),
  );

  // All four gates ran and passed; the verdict is the machine record.
  expect(verdict.passed, isTrue);
  expect(verdict.routes.evidence, containsAll(<String>['/login', '/register']));
  expect(verdict.di.evidence, hasLength(4), reason: 'token@flavor pairs');
  expect(verdict.encode(), contains('"tokensResolved": 4'));
}
