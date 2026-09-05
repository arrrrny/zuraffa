// GENERATED TEST SUBJECT — `zfa tdd gen U5` (spec 044-test-tdd-generation).
//
// behavior_id: U5
// Implemented for feature 078-skin-contract-schema (issue #1164): the
// subject drives the REAL contract model/parser/emitter — the smallest
// change that makes the certified-red test pass (TDD green step).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/skin_contract_schema.dart';

const validContractJson = '''
{
  "schemaVersion": "1",
  "routes": [
    { "path": "/login", "view": "LoginPage" }
  ],
  "states": [
    { "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }
  ],
  "platformRows": [
    { "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }
  ],
  "stateRows": [
    { "view": "LoginPage", "row": "error-toaster", "kind": "observer" }
  ]
}
''';

/// Scenario runner for behavior U5.
Future<void> subject_u5() async {
  final schema = skinContractSchema();
  final defs = schema[r'$defs'] as Map<String, dynamic>;
  final routeDef = defs['contractRoutes'] as Map<String, dynamic>;
  final pathSchema =
      (routeDef['properties'] as Map<String, dynamic>)['path']
          as Map<String, dynamic>;
  expect(pathSchema['pattern'], '^/');
  final stateDef = defs['contractStates'] as Map<String, dynamic>;
  final errorSchema =
      (stateDef['properties'] as Map<String, dynamic>)['error']
          as Map<String, dynamic>;
  expect(errorSchema['enum'], contains('toaster'));
}
