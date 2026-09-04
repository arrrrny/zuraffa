// GENERATED subject — implemented (issue #960 A3).
//
// Verifies byte-for-byte determinism: emitting the same declared row
// twice produces byte-identical artifacts.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

void subject_a3() {
  final contract = DependencyContract.parseRow(
    name: 'FirebaseAuth',
    type: 'service',
    contract: 'signIn(email, password) -> User, signOut() -> void',
    priority: 'P1',
  );
  final first = DependencyMockBuilder.emit(
    contract: contract,
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  final second = DependencyMockBuilder.emit(
    contract: contract,
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  expect(first.length, equals(second.length));
  for (var i = 0; i < first.length; i++) {
    expect(second[i].path, equals(first[i].path));
    expect(
      second[i].content,
      equals(first[i].content),
      reason: 'regeneration must be byte-identical (${first[i].path})',
    );
  }
}
