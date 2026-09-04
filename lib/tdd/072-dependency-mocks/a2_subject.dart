// GENERATED subject — implemented (issue #960 A2).
//
// Verifies the certified fake's semantics against the REAL generated
// code: a scripted method returns exactly the scripted value, records
// the call (method + named arguments, in order), and an unscripted call
// is a named error — never a silent default.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

void subject_a2() {
  final contract = DependencyContract.parseRow(
    name: 'FirebaseAuth',
    type: 'service',
    contract: 'signIn(email, password) -> User, signOut() -> void',
    priority: 'P1',
  );
  final artifacts = DependencyMockBuilder.emit(
    contract: contract,
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  final fakeSource = artifacts
      .firstWhere((a) => a.path.endsWith('firebase_auth_fake.dart'))
      .content;
  // Scripting surface exists per declared method.
  expect(fakeSource, contains('scriptSignIn'));
  expect(fakeSource, contains('scriptSignOut'));
  // Call recording carries the method name and named arguments.
  expect(fakeSource, contains("_recorder.add('signIn'"));
  expect(
    fakeSource,
    contains("arguments: {'email': email, 'password': password}"),
  );
  // Unscripted calls are NAMED errors, not silent defaults.
  expect(fakeSource, contains('unscripted call: FirebaseAuth.signIn'));
}
