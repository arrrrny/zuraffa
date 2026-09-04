// GENERATED subject — implemented (issue #960 U2 / FR-002).
//
// The generated package exposes EXACTLY the declared surface: member
// for member, no invented, missing, or renamed members.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u2() {
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
  final interface = artifacts
      .firstWhere((a) => a.path.endsWith('firebase_auth.dart'))
      .content;
  final memberLines = interface
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.endsWith(';') && l.contains('('))
      .toList();
  expect(
    memberLines,
    equals(<String>[
      'Future<User> signIn(String email, String password);',
      'Future<void> signOut();',
    ]),
    reason: 'member-for-member equality with the declared contract',
  );
  return null;
}
