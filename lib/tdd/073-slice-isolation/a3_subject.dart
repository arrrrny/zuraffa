// IMPLEMENTED (073 phase 2, issue #961): AC-3 — a declared route
// resolves through the mock DI bindings: the route table returns the
// declared page, the DI locator produces the bound certified mock, and
// an undeclared route refuses naming the path.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_scaffold.dart';

import 'sandbox_fixture.dart';

void subject_a3() {
  // The declared routes resolve to their pages, exactly.
  final routes = SliceRouteTable(const [
    SandboxRoute(path: '/login', page: 'LoginPage'),
    SandboxRoute(path: '/register', page: 'RegisterPage'),
  ]);
  expect(routes.resolve('/login'), equals('LoginPage'));
  expect(routes.resolve('/register'), equals('RegisterPage'));
  expect(routes.routes.keys, equals(const ['/login', '/register']));

  // An undeclared route refuses, naming the path.
  String refusal;
  try {
    routes.resolve('/settings');
    refusal = 'no refusal';
  } on StateError catch (e) {
    refusal = e.message.toString();
  }
  expect(refusal, contains('/settings'));
  expect(refusal, contains('--> fix:'));

  // Through the mock DI: the declared dependency resolves to its
  // certified mock binding (registration-order stable, cached).
  final locator = SandboxLocator();
  final mock = Object();
  locator.bind('dependencies/firebase_auth', () => mock);
  expect(identical(locator.resolve('dependencies/firebase_auth'), mock), isTrue,
      reason: 'the bound certified mock is what the shell renders against');
  // An unbound touchpoint refuses rather than silently returning null.
  expect(() => locator.resolve('dependencies/missing'), throwsStateError);
}
