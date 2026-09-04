// IMPLEMENTED (074 phase 2, issue #962): AC-1 — the host's route
// barrel is regenerated to include the feature's routes, additively
// and deterministically; hand-edited host routing never happens.
library;

import 'package:test/test.dart';

import 'merge_fixture.dart';

void subject_a1() {
  final regenerated = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  );
  expect(regenerated.passed, isTrue, reason: regenerated.conflicts.join('\n'));
  expect(regenerated.barrel, contains("route('/login', page: LoginPage()"),
      reason: 'the feature route is in the barrel');
  expect(regenerated.barrel, contains("route('/register', page: RegisterPage()"));
  // Existing host entries survive verbatim (additive).
  expect(regenerated.barrel, contains("route('/home', page: HomePage()"));
  expect(regenerated.barrel, contains("route('/settings', page: SettingsPage()"));
}
