// IMPLEMENTED (073 phase 2, issue #961): AC-1 — a real cut of the
// declared login feature yields the full runnable-sandbox inventory:
// spec + tdd artifacts, app shell, router harness exposing exactly the
// declared routes, and DI wiring binding certified mocks for every
// declared dependency.
library;

import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<void> subject_a1() async {
  final host = writeHostProject();
  final result = await cutSandbox(host);
  expect(result.success, isTrue, reason: result.message);

  final sandbox = sandboxDirOf(host);
  for (final receipt in <String>[
    'specs/$fixtureFeature/spec.md',
    'specs/$fixtureFeature/tdd/journal.json',
    'specs/$fixtureFeature/tdd/artifacts.json',
  ]) {
    readSandboxFile(sandbox, receipt);
  }
  final shell = readSandboxFile(sandbox, 'lib/main.dart');
  expect(shell, contains('class SliceApp extends StatelessWidget'));
  final router = readSandboxFile(sandbox, 'lib/router.dart');
  expect(router, contains("'/login': (ctx) => LoginPage(),"));
  expect(router, contains("'/register': (ctx) => RegisterPage(),"));
  final di = readSandboxFile(sandbox, 'lib/di.dart');
  for (final token in const [
    "sandbox.bind('dependencies/firebase_auth'",
    "sandbox.bind('dependencies/go_router_host'",
    "sandbox.bind('dependencies/secure_store'",
  ]) {
    expect(di, contains(token), reason: 'certified mock must be bound');
  }
  for (final fake in fixtureFakes) {
    readSandboxFile(sandbox, fake);
  }
}
