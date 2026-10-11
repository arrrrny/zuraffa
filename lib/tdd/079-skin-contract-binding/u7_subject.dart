// GENERATED TEST SUBJECT — `zfa tdd gen U7` (spec 044-test-tdd-generation).
//
// behavior_id: U7
// Implemented for feature 079-skin-contract-binding (issue #1165): the
// subject drives the REAL runtime binding — the TDD green step.
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/skin.dart';

Future<void> subject_u7() async {
  // The binding surface resolves through the skin barrel — the
  // cross-package import the Flutter shell uses.
  const binding = SkinContractRuntimeBinding(
    name: 'x',
    routeTable: RouteContractTable(allowedRoutes: {}),
    declaredRoutes: [ContractRoute(path: '/', view: 'HomeView')],
    stateBindings: {},
    auditRows: [],
  );
  expect(binding.name, 'x');
  expect(parseSkinContractDeclaration, isNotNull);
}
