// GENERATED subject — implemented (issue #960 A1).
//
// Verifies the behavior end to end against the REAL source: the
// FirebaseAuth contract parses and the builder emits an interface whose
// members are exactly the declared ones — no invented, missing, or
// renamed members.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

void subject_a1() {
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
  // Declared members present, with their declared signatures.
  expect(
    interface,
    contains('Future<User> signIn(String email, String password);'),
    reason: 'the declared signIn member must be generated',
  );
  expect(
    interface,
    contains('Future<void> signOut();'),
    reason: 'the declared signOut member must be generated',
  );
  // No invented members: every other member-shaped line must be one of
  // the two declared ones.
  final memberLines = interface
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.endsWith(';') && l.contains('('))
      .toList();
  expect(memberLines, hasLength(2), reason: 'exactly the declared members');
}
