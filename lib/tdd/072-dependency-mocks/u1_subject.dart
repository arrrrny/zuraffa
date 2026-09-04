// GENERATED subject — implemented (issue #960 U1 / FR-001).
//
// The dependency declaration reader loads declared rows (name, type,
// contract, priority, spec line) — the ground the command reads; an
// undeclared name has no row and the command's refusal contract covers
// it (exit 2, A4/FR-001 acceptance).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u1() {
  // The declared row parses into the typed contract the command serves.
  final contract = DependencyContract.parseRow(
    name: 'FirebaseAuth',
    type: 'service',
    contract: 'signIn(email, password) -> User, signOut() -> void',
    priority: 'P1',
    specLine: 42,
  );
  expect(contract.name, equals('FirebaseAuth'));
  expect(contract.type, equals('service'));
  expect(contract.signatures, hasLength(2));
  expect(contract.signatures[0].name, equals('signIn'));
  expect(contract.signatures[0].parameters, equals(['email', 'password']));
  expect(contract.signatures[0].returnType, equals('User'));
  expect(contract.signatures[1].name, equals('signOut'));
  expect(contract.priority.label, equals('p1'));
  expect(contract.specLine, equals(42));
  return null;
}
