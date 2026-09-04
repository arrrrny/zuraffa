// IMPLEMENTED (073 phase 2, issue #961): the real cut, exercised end
// to end — a fixture host declaring the login feature, cut through the
// real CutSliceCapability, must yield a sandbox carrying the feature's
// spec + tdd receipts, a runnable shell, a router harness exposing
// exactly the declared routes, and mock-DI bindings for every declared
// dependency (FR-001).
//
// Async subject: the assertions run inside the test zone — a failed
// expect surfaces as an unhandled async error and fails the test.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<Object?> subject_u1() async {
  final host = writeHostProject();
  addTearDown(() => host.deleteSync(recursive: true));

  final result = await cutSandbox(host);
  expect(result.success, isTrue, reason: result.message);

  final sandbox = sandboxDirOf(host);
  // The receipts travel: spec + tdd artifacts (journal, registry).
  readSandboxFile(sandbox, 'specs/$fixtureFeature/spec.md');
  readSandboxFile(sandbox, 'specs/$fixtureFeature/tdd/journal.json');
  readSandboxFile(sandbox, 'specs/$fixtureFeature/tdd/artifacts.json');
  // The runnable composition: shell, router harness, mock DI.
  final main = readSandboxFile(sandbox, 'lib/main.dart');
  final router = readSandboxFile(sandbox, 'lib/router.dart');
  readSandboxFile(sandbox, 'lib/di.dart');
  // Certified fakes for every declared dependency.
  for (final fake in fixtureFakes) {
    readSandboxFile(sandbox, fake);
  }

  final di = readSandboxFile(sandbox, 'lib/di.dart');
  expect(di, contains("sandbox.bind('dependencies/firebase_auth'"));
  expect(di, contains("sandbox.bind('dependencies/go_router_host'"));
  expect(di, contains("sandbox.bind('dependencies/secure_store'"));

  expect(router, contains("'/login': (ctx) => LoginPage(),"));
  expect(router, contains("'/register': (ctx) => RegisterPage(),"));
  // EXACTLY the declared routes: an undeclared path is not routable.
  expect(router.contains("'/settings'"), isFalse, reason: router);

  expect(main, contains('bindSandboxDependencies();'));
  expect(main, contains('runApp(SliceApp());'));
  expect(p.relative(sandbox, from: host.path), startsWith('.zuraffa/slices/'));
  return null;
}
