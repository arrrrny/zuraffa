// IMPLEMENTED (074 phase 2, issue #962): FR-002 — every declared route
// path resolves to the feature's page in the merged host (the pure
// resolution check, per-route offenders).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';

import 'merge_fixture.dart';

void subject_u2() {
  final barrel = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  ).barrel;

  // /login -> LoginPage, /register -> RegisterPage.
  expect(
    RouteBarrel.resolutionOffenders(
      barrelSource: barrel,
      declared: featureRoutes,
    ),
    isEmpty,
  );

  // A drifted page is caught per-route, naming the path.
  final drifted = RouteBarrel.resolutionOffenders(
    barrelSource: barrel,
    declared: const [
      RouteDecl(path: '/login', page: 'OtherPage', module: 'login'),
    ],
  );
  expect(drifted, hasLength(1));
  expect(drifted.single, contains("'/login'"));
  expect(drifted.single, contains('OtherPage'));
}
