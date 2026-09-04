// GENERATED subject — implemented (issue #960 U10 / FR-010).
//
// Generated dependency-mock artifacts carry a registry record traceable
// to the dependency row and feature.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/builders/dependency_mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/dependency_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/models/dependency_contract.dart';

Object? subject_u10() {
  final contract = DependencyContract.parseRow(
    name: 'FirebaseAuth',
    type: 'service',
    contract: 'signIn(email, password) -> User, signOut() -> void',
    priority: 'P1',
    specLine: 12,
  );
  final artifacts = DependencyMockBuilder.emit(
    contract: contract,
    outDir: 'test/mock/dependencies/firebase_auth',
  );
  final record = DependencyMockCapability.registryRecordFor(
    contract: contract,
    artifactPaths: artifacts.map((a) => a.path).toList(),
    feature: '072-dependency-mocks',
  );
  expect(
    record['behavior_id'],
    equals('dependency:FirebaseAuth'),
    reason: 'the record is keyed to the dependency row',
  );
  expect(record['source_criterion'], equals('spec line 12'));
  expect(record['feature'], equals('072-dependency-mocks'));
  expect(record['test_path'], equals(artifacts.first.path));
}
