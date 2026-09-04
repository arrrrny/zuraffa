// GENERATED subject — implemented (issue #960 U9 / FR-009).
//
// Realize parity against the DECLARED contract: a conforming adapter
// passes; surface drift names the drifted member and the row.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';
import 'package:zuraffa/src/plugins/mock/services/dependency_parity.dart';

Object? subject_u9() {
  final declared = DependencyContract.parseRow(
    name: 'FirebaseAuth',
    type: 'service',
    contract: 'signIn(email, password) -> User, signOut() -> void',
    priority: 'P1',
  );
  // Conforming adapter: every declared member implemented.
  final ok = DependencyParity.check(
    contract: declared,
    adapterMembers: const [
      'signIn(String email, String password)',
      'signOut()',
    ],
  );
  expect(ok.driftedMembers, isEmpty, reason: 'conforming adapter passes');

  // Drifting adapter: a missing member is named, with the row.
  final drifted = DependencyParity.check(
    contract: declared,
    adapterMembers: const ['signOut()'],
  );
  expect(drifted.driftedMembers, equals(['signIn']));
  expect(
    drifted.fixHint,
    contains('FirebaseAuth'),
    reason: 'the fix names the declared row',
  );
  return null;
}
