// GENERATED subject — implemented (issue #960 U4 / FR-004).
//
// Determinism: unchanged row → byte-identical artifacts; changed row →
// deterministic regeneration whose change is detectable.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u4() {
  const row = {
    'name': 'FirebaseAuth',
    'type': 'service',
    'contract': 'signIn(email, password) -> User, signOut() -> void',
    'priority': 'P1',
  };
  DependencyContract parse(Map<String, String> r) => DependencyContract.parseRow(
        name: r['name']!,
        type: r['type']!,
        contract: r['contract']!,
        priority: r['priority'],
      );
  final first = DependencyMockBuilder.emit(
    contract: parse(row),
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  final second = DependencyMockBuilder.emit(
    contract: parse(row),
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  for (var i = 0; i < first.length; i++) {
    expect(second[i].content, equals(first[i].content));
  }
  // A changed row regenerates deterministically (different contract →
  // different bytes, same layout).
  final changed = DependencyMockBuilder.emit(
    contract: parse({
      ...row,
      'contract': 'signIn(email, password) -> User',
    }),
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  expect(changed.length, equals(first.length));
  expect(
    changed.first.content,
    isNot(equals(first.first.content)),
    reason: 'the change must be visible in the regenerated artifacts',
  );
  return null;
}
