// GENERATED subject — implemented (issue #960 A4).
//
// Verifies the undeclared-name refusal: `DependencyMockCapability.run`
// exits non-zero (2) with the row-to-add fix hint, instead of guessing.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/dependency_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void subject_a4() {
  // The capability class must exist and carry the refusal contract:
  // the undeclared-name exit code is 2 and the fix hint names the
  // declared table. Exercised through the class contract (no process
  // spawn in the unit lane).
  final capability = DependencyMockCapability(MockPlugin(outputDir: 'test'));
  expect(capability.name, equals('dependency'));
  expect(
    DependencyMockCapability.exitUndeclared,
    equals(2),
    reason: 'undeclared name refuses with exit 2',
  );
  // And the refusal path itself: run with no resolvable feature → the
  // declaration reader errors, run() maps it to exit 2.
  final exit = DependencyMockCapability.runForTest(
    name: 'Vendure',
    projectRoot: '.',
  );
  expect(exit, equals(2));
  expect(
    DependencyMockCapability.fixHint,
    contains('External Dependencies & Contracts'),
  );
}
