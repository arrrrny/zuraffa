// IMPLEMENTED (073 phase 2, issue #961): deterministic scaffolding —
// two cuts with identical declared facts into different hosts produce
// byte-identical generated wiring (FR-007).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<Object?> subject_u7() async {
  final hostA = writeHostProject();
  final hostB = writeHostProject();
  addTearDown(() => hostA.deleteSync(recursive: true));
  addTearDown(() => hostB.deleteSync(recursive: true));

  final cutA = await cutSandbox(hostA);
  final cutB = await cutSandbox(hostB);
  expect(cutA.success, isTrue, reason: cutA.message);
  expect(cutB.success, isTrue, reason: cutB.message);

  final sandboxA = sandboxDirOf(hostA);
  final sandboxB = sandboxDirOf(hostB);
  for (final wiring in fixtureWiring) {
    final bytesA = File(p.join(sandboxA, wiring)).readAsStringSync();
    final bytesB = File(p.join(sandboxB, wiring)).readAsStringSync();
    expect(
      bytesA,
      equals(bytesB),
      reason: 'wiring must be byte-identical across identical cuts: $wiring',
    );
    expect(bytesA, isNotEmpty, reason: wiring);
  }
  // The DI bindings carry the same certified tokens in both cuts.
  final diA = File(p.join(sandboxA, 'lib', 'di.dart')).readAsStringSync();
  expect(diA, contains("sandbox.bind('dependencies/firebase_auth'"));
  expect(diA, contains("sandbox.bind('dependencies/secure_store'"));
  return null;
}
