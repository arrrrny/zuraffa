// GENERATED subject — implemented (issue #960 U8 / FR-008).
//
// Malformed rows refuse naming the defect: unparseable signatures,
// unknown priority, duplicates. Nothing malformed ever produces a
// generated artifact.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u8() {
  // Unparseable signature → FormatException naming the segment.
  expect(
    () => DependencyContract.parseRow(
      name: 'Auth',
      type: 'service',
      contract: 'signIn email password -> User',
      priority: 'P1',
    ),
    throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains('signIn email password -> User'),
      ),
    ),
  );
  // Unknown priority → FormatException naming the cell.
  expect(
    () => DependencyContract.parseRow(
      name: 'Auth',
      type: 'service',
      contract: 'signOut() -> void',
      priority: 'P9',
    ),
    throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains('P9'),
      ),
    ),
  );
  return null;
}
