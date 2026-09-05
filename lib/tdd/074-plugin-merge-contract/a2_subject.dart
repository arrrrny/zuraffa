// IMPLEMENTED (074 phase 2, issue #962): AC-2 — every declared route
// path resolves to the feature's page through the regenerated table.
library;

import 'package:test/test.dart';

import 'merge_fixture.dart';

void subject_a2() {
  final regenerated = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  );
  expect(regenerated.passed, isTrue);

  final offenders = RouteBarrel.resolutionOffenders(
    barrelSource: regenerated.barrel,
    declared: featureRoutes,
  );
  expect(offenders, isEmpty, reason: offenders.join('\n'));

  // A missing route is named (resolution is a real check, not a vibe).
  final broken = RouteBarrel.resolutionOffenders(
    barrelSource: hostBarrel,
    declared: featureRoutes,
  );
  expect(broken, hasLength(featureRoutes.length));
  expect(broken.join(' '), contains("'/login'"));
  expect(broken.join(' '), contains('--> fix:'));
}
