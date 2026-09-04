// GENERATED subject — implemented (issue #960 U3 / FR-003).
//
// The package includes the certified fake: scriptable per-method
// responses and call recording sufficient for interaction assertions.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u3() {
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
  // Scriptable per-method responses.
  expect(fakeSource, contains('scriptSignIn('));
  expect(fakeSource, contains('scriptSignOut('));
  // Call recording: method + named arguments + order.
  expect(fakeSource, contains('_CallRecorder'));
  expect(fakeSource, contains('_recorder.add('));
  expect(fakeSource, contains('callsTo('));
  return null;
}
